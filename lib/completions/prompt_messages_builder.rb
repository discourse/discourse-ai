# frozen_string_literal: true
#
module DiscourseAi
  module Completions
    class PromptMessagesBuilder
      MAX_CHAT_UPLOADS = 5
      MAX_TOPIC_UPLOADS = 5
      attr_reader :chat_context_posts
      attr_reader :chat_context_post_upload_ids
      attr_accessor :topic

      def self.messages_from_chat(
        message,
        channel:,
        context_post_ids:,
        max_messages:,
        include_uploads:,
        bot_user_ids:,
        instruction_message: nil
      )
        include_thread_titles = !channel.direct_message_channel? && !message.thread_id

        current_id = message.id
        messages = nil

        if !message.thread_id && channel.direct_message_channel?
          messages = [message]
        elsif !channel.direct_message_channel? && !message.thread_id
          messages =
            Chat::Message
              .joins("left join chat_threads on chat_threads.id = chat_messages.thread_id")
              .where(chat_channel_id: channel.id)
              .where(
                "chat_messages.thread_id IS NULL OR chat_threads.original_message_id = chat_messages.id",
              )
              .order(id: :desc)
              .limit(max_messages)
              .to_a
              .reverse
        end

        messages ||=
          ChatSDK::Thread.last_messages(
            thread_id: message.thread_id,
            guardian: Discourse.system_user.guardian,
            page_size: max_messages,
          )

        builder = new

        guardian = Guardian.new(message.user)
        if context_post_ids
          builder.set_chat_context_posts(
            context_post_ids,
            guardian,
            include_uploads: include_uploads,
          )
        end

        messages.each do |m|
          # restore stripped message
          m.message = instruction_message if m.id == current_id && instruction_message

          if bot_user_ids.include?(m.user_id)
            builder.push(type: :model, content: m.message)
          else
            upload_ids = nil
            upload_ids = m.uploads.map(&:id) if include_uploads && m.uploads.present?
            mapped_message = m.message

            thread_title = nil
            thread_title = m.thread&.title if include_thread_titles && m.thread_id
            mapped_message = "(#{thread_title})\n#{m.message}" if thread_title

            builder.push(
              type: :user,
              content: mapped_message,
              name: m.user.username,
              upload_ids: upload_ids,
            )
          end
        end

        builder.to_a(
          limit: max_messages,
          style: channel.direct_message_channel? ? :chat_with_context : :chat,
        )
      end

      def self.messages_from_post(post, style: nil, max_posts:, bot_usernames:, include_uploads:)
        # Pay attention to the `post_number <= ?` here.
        # We want to inject the last post as context because they are translated differently.

        post_types = [Post.types[:regular]]
        post_types << Post.types[:whisper] if post.post_type == Post.types[:whisper]

        context =
          post
            .topic
            .posts
            .joins(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .order("post_number desc")
            .where("post_type in (?)", post_types)
            .limit(max_posts)
            .pluck(
              "posts.raw",
              "users.username",
              "post_custom_prompts.custom_prompt",
              "(
                  SELECT array_agg(ref.upload_id)
                  FROM upload_references ref
                  WHERE ref.target_type = 'Post' AND ref.target_id = posts.id
               ) as upload_ids",
            )

        builder = new
        builder.topic = post.topic

        context.reverse_each do |raw, username, custom_prompt, upload_ids|
          custom_prompt_translation =
            Proc.new do |message|
              # We can't keep backwards-compatibility for stored functions.
              # Tool syntax requires a tool_call_id which we don't have.
              if message[2] != "function"
                custom_context = {
                  content: message[0],
                  type: message[2].present? ? message[2].to_sym : :model,
                }

                custom_context[:id] = message[1] if custom_context[:type] != :model
                custom_context[:name] = message[3] if message[3]

                thinking = message[4]
                custom_context[:thinking] = thinking if thinking

                builder.push(**custom_context)
              end
            end

          if custom_prompt.present?
            custom_prompt.each(&custom_prompt_translation)
          else
            context = { content: raw, type: (bot_usernames.include?(username) ? :model : :user) }

            context[:id] = username if context[:type] == :user

            if upload_ids.present? && context[:type] == :user && include_uploads
              context[:upload_ids] = upload_ids.compact
            end

            builder.push(**context)
          end
        end

        builder.to_a(style: style || (post.topic.private_message? ? :bot : :topic))
      end

      def initialize
        @raw_messages = []
      end

      def set_chat_context_posts(post_ids, guardian, include_uploads:)
        posts = []
        Post
          .where(id: post_ids)
          .order("id asc")
          .each do |post|
            next if !guardian.can_see?(post)
            posts << post
          end
        if posts.present?
          posts_context =
            +"\nThis chat is in the context of the Discourse topic '#{posts[0].topic.title}':\n\n"
          posts_context = +"{{{\n"
          posts.each do |post|
            posts_context << "url: #{post.url}\n"
            posts_context << "#{post.username}: #{post.raw}\n\n"
          end
          posts_context << "}}}"
          @chat_context_posts = posts_context
          if include_uploads
            uploads = []
            posts.each { |post| uploads.concat(post.uploads.pluck(:id)) }
            uploads.uniq!
            @chat_context_post_upload_ids = uploads.take(MAX_CHAT_UPLOADS)
          end
        end
      end

      def to_a(limit: nil, style: nil)
        return chat_array(limit: limit) if style == :chat
        return topic_array if style == :topic
        result = []

        # this will create a "valid" messages array
        # 1. ensures we always start with a user message
        # 2. ensures we always end with a user message
        # 3. ensures we always interleave user and model messages
        last_type = nil
        @raw_messages.each do |message|
          next if !last_type && message[:type] != :user

          if last_type == :tool_call && message[:type] != :tool
            result.pop
            last_type = result.length > 0 ? result[-1][:type] : nil
          end

          next if message[:type] == :tool && last_type != :tool_call

          if message[:type] == last_type
            # merge the message for :user message
            # replace the message for other messages
            last_message = result[-1]

            if message[:type] == :user
              old_name = last_message.delete(:name)
              last_message[:content] = ["#{old_name}: ", last_message[:content]].flatten if old_name

              new_content = message[:content]
              new_content = ["#{message[:name]}: ", new_content].flatten if message[:name]

              if !last_message[:content].is_a?(Array)
                last_message[:content] = [last_message[:content]]
              end
              last_message[:content].concat(["\n", new_content].flatten)

              compressed =
                compress_messages_buffer(last_message[:content], max_uploads: MAX_TOPIC_UPLOADS)
              last_message[:content] = compressed
            else
              last_message[:content] = message[:content]
            end
          else
            result << message
          end

          last_type = message[:type]
        end

        if style == :chat_with_context && @chat_context_posts
          buffer = +"You are replying inside a Discourse chat."
          buffer << "\n"
          buffer << @chat_context_posts
          buffer << "\n"
          buffer << "Your instructions are:\n"
          result[0][:content] = "#{buffer}#{result[0][:content]}"
          if @chat_context_post_upload_ids.present?
            result[0][:upload_ids] = (result[0][:upload_ids] || []).concat(
              @chat_context_post_upload_ids,
            )
          end
        end

        if limit
          result[0..limit]
        else
          result
        end
      end

      def push(type:, content:, name: nil, upload_ids: nil, id: nil, thinking: nil)
        if !%i[user model tool tool_call system].include?(type)
          raise ArgumentError, "type must be either :user, :model, :tool, :tool_call or :system"
        end
        raise ArgumentError, "upload_ids must be an array" if upload_ids && !upload_ids.is_a?(Array)

        content = [content, *upload_ids.map { |upload_id| { upload_id: upload_id } }] if upload_ids
        message = { type: type, content: content }
        message[:name] = name.to_s if name
        message[:id] = id.to_s if id
        if thinking
          message[:thinking] = thinking["thinking"] if thinking["thinking"]
          message[:thinking_signature] = thinking["thinking_signature"] if thinking[
            "thinking_signature"
          ]
          message[:redacted_thinking_signature] = thinking[
            "redacted_thinking_signature"
          ] if thinking["redacted_thinking_signature"]
        end

        @raw_messages << message
      end

      private

      def topic_array
        raw_messages = @raw_messages.dup
        content_array = []
        content_array << "You are operating in a Discourse forum.\n\n"

        if @topic
          if @topic.private_message?
            content_array << "Private message info.\n"
          else
            content_array << "Topic information:\n"
          end

          content_array << "- URL: #{@topic.url}\n"
          content_array << "- Title: #{@topic.title}\n"
          if SiteSetting.tagging_enabled
            tags = @topic.tags.pluck(:name)
            tags -= DiscourseTagging.hidden_tag_names if tags.present?
            content_array << "- Tags: #{tags.join(", ")}\n" if tags.present?
          end
          if !@topic.private_message?
            content_array << "- Category: #{@topic.category.name}\n" if @topic.category
          end
          content_array << "- Number of replies: #{@topic.posts_count - 1}\n\n"
        end

        last_user_message = raw_messages.pop

        if raw_messages.present?
          content_array << "Here is the conversation so far:\n"
          raw_messages.each do |message|
            content_array << "#{message[:name] || "User"}: "
            content_array << message[:content]
            content_array << "\n\n"
          end
        end

        if last_user_message
          content_array << "You are responding to #{last_user_message[:name] || "User"} who just said:\n"
          content_array << last_user_message[:content]
        end

        content_array =
          compress_messages_buffer(content_array.flatten, max_uploads: MAX_TOPIC_UPLOADS)

        user_message = { type: :user, content: content_array }

        [user_message]
      end

      def chat_array(limit:)
        if @raw_messages.length > 1
          buffer = [
            +"You are replying inside a Discourse chat channel. Here is a summary of the conversation so far:\n{{{",
          ]

          @raw_messages[0..-2].each do |message|
            buffer << "\n"

            if message[:type] == :user
              buffer << "#{message[:name] || "User"}: "
            else
              buffer << "Bot: "
            end

            buffer << message[:content]
          end

          buffer << "\n}}}"
          buffer << "\n\n"
          buffer << "Your instructions:"
          buffer << "\n"
        end

        last_message = @raw_messages[-1]
        buffer << "#{last_message[:name] || "User"}: "
        buffer << last_message[:content]

        buffer = compress_messages_buffer(buffer.flatten, max_uploads: MAX_CHAT_UPLOADS)

        message = { type: :user, content: buffer }
        [message]
      end

      # caps uploads to maximum uploads allowed in message stream
      # and concats string elements
      def compress_messages_buffer(buffer, max_uploads:)
        compressed = []
        current_text = +""
        upload_count = 0

        buffer.each do |item|
          if item.is_a?(String)
            current_text << item
          elsif item.is_a?(Hash)
            compressed << current_text if current_text.present?
            compressed << item
            current_text = +""
            upload_count += 1
          end
        end

        compressed << current_text if current_text.present?

        if upload_count > max_uploads
          counter = max_uploads - upload_count
          compressed.delete_if { |item| item.is_a?(Hash) && (counter += 1) > 0 }
        end

        compressed = compressed[0] if compressed.length == 1 && compressed[0].is_a?(String)

        compressed
      end
    end
  end
end
