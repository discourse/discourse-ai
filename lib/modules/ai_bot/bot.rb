# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      attr_reader :bot_user

      BOT_NOT_FOUND = Class.new(StandardError)

      def self.as(bot_user)
        available_bots = [DiscourseAi::AiBot::OpenAiBot, DiscourseAi::AiBot::AnthropicBot]

        bot =
          available_bots.detect(-> { raise BOT_NOT_FOUND }) do |bot_klass|
            bot_klass.can_reply_as?(bot_user)
          end

        bot.new(bot_user)
      end

      def initialize(bot_user)
        @bot_user = bot_user
      end

      def update_pm_title(post)
        prompt = [title_prompt(post)]

        new_title = get_updated_title(prompt)

        PostRevisor.new(post.topic.first_post, post.topic).revise!(
          bot_user,
          title: new_title.sub(/\A"/, "").sub(/"\Z/, ""),
        )
      end

      def debug(prompt)
        return if !Rails.env.development?
        if prompt.is_a?(Array)
          prompt.each { |p| p.keys.each { |k| puts "#{k}: #{p[k]}" } }
        else
          p prompt
        end
      end

      def stream_reply(post:, bot_reply_post:, prefer_low_cost: false)
        redis_stream_key = nil
        start = Time.now

        setup_cancel = false
        context = {}

        prompt = bot_prompt_with_topic_context(post)
        # TODO remove
        debug(prompt)

        reply = +(bot_reply_post&.raw || "").dup
        reply << "\n\n" if reply.length > 0

        submit_prompt(prompt, prefer_low_cost: prefer_low_cost) do |partial, cancel|
          reply << get_delta(partial, context)

          if redis_stream_key && !Discourse.redis.get(redis_stream_key)
            cancel&.call

            bot_reply_post.update!(raw: reply, cooked: PrettyText.cook(reply)) if bot_reply_post
          end

          next if reply.length < SiteSetting.min_personal_message_post_length
          # Minor hack to skip the delay during tests.
          next if (Time.now - start < 0.5) && !Rails.env.test?

          if bot_reply_post
            Discourse.redis.expire(redis_stream_key, 60)
            start = Time.now

            publish_update(bot_reply_post, raw: reply.dup)
          else
            bot_reply_post = create_bot_reply(post, reply)
          end

          if !setup_cancel && bot_reply_post
            redis_stream_key = "gpt_cancel:#{bot_reply_post.id}"
            Discourse.redis.setex(redis_stream_key, 60, 1)
            setup_cancel = true
          end
        end

        if bot_reply_post
          publish_update(bot_reply_post, done: true)

          bot_reply_post.revise(
            bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )

          bot_reply_post.post_custom_prompt ||=
            bot_reply_post.build_post_custom_prompt(custom_prompt: [])
          prompt = [reply, bot_user.username]
          bot_reply_post.post_custom_prompt.update!(custom_prompt: prompt)
        end
      end

      def create_bot_reply(post, raw)
        PostCreator.create!(bot_user, topic_id: post.topic_id, raw: raw, skip_validations: false)
      end

      def context_prompt(post, context, result_name)
        ["Given the #{result_name} data:\n #{context}\nAnswer: #{post.raw}", post.user.username]
      end

      def reply_to(post)
        command = triage_post(post)

        if raw = command.pre_raw_details
          bot_reply_post = create_bot_reply(post, raw)
        end

        if context = command.process
          if context
            post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
            prompt = post.post_custom_prompt.custom_prompt || []
            # TODO consider providing even more context
            prompt << context_prompt(post, context, command.result_name)
            post.post_custom_prompt.update!(custom_prompt: prompt)
          end
        end

        if raw = command.post_raw_details
          if bot_reply_post
            bot_reply_post.revise(
              bot_user,
              { raw: raw },
              skip_validations: true,
              skip_revision: true,
            )
          else
            bot_reply_post = create_bot_reply(post, raw)
          end
        end

        stream_reply(post: post, bot_reply_post: bot_reply_post) if command.chain_next_response
      rescue => e
        if Rails.env.development?
          p e
          puts e.backtrace
        end
        raise e if Rails.env.test?
        Discourse.warn_exception(e, message: "ai-bot: Reply failed")
      end

      def triage_params
        { temperature: 0.1, max_tokens: 100 }
      end

      def triage_post(post)
        prompt = bot_prompt_with_topic_context(post, triage: true)

        debug(prompt)

        reply = +""
        context = {}
        submit_prompt(prompt, **triage_params) do |partial, cancel|
          reply << get_delta(partial, context)
        end

        debug(reply)

        cmd_text = reply.strip.split("\n").detect { |l| l[0] == "!" }

        args = nil

        if cmd_text
          command_name, args = cmd_text[1..-1].strip.split(" ", 2)
          command_klass = available_commands.detect { |cmd| cmd.should_invoke?(command_name) }
        end
        command_klass = command_klass || Commands::NoopCommand

        command_klass.new(bot_user, post, args)
      end

      def bot_prompt_with_topic_context(post, triage: false)
        messages = []
        conversation = conversation_context(post)

        rendered_system_prompt = system_prompt(post, triage: triage)

        total_prompt_tokens = tokenize(rendered_system_prompt).length

        last = true
        messages = []
        conversation.each do |raw, username|
          break if total_prompt_tokens >= prompt_limit

          tokens = tokenize(raw)

          while !raw.blank? && tokens.length + total_prompt_tokens > prompt_limit
            raw = raw[0..-100] || ""
            tokens = tokenize(raw)
          end

          next if raw.blank?

          total_prompt_tokens += tokens.length

          if triage && last
            raw = "Given the user input:\n#{raw}\n\nWhat !command should you issue?\n" if triage
          end

          messages.unshift(build_message(username, raw, last: last))
          last = false
        end

        messages.unshift(build_message(bot_user.username, rendered_system_prompt, system: true))
        messages
      end

      def prompt_limit
        raise NotImplemented
      end

      def title_prompt(post)
        build_message(bot_user.username, <<~TEXT)
          Suggest a 7 word title for the following topic without quoting any of it:

          #{post.topic.posts[1..-1].map(&:raw).join("\n\n")[0..prompt_limit]}
        TEXT
      end

      def available_commands
        @cmds ||=
          begin
            cmds = [
              Commands::CategoriesCommand,
              Commands::TimeCommand,
              Commands::SearchCommand,
              Commands::SummarizeCommand,
            ]

            cmds << Commands::TagsCommand if SiteSetting.tagging_enabled
            cmds << Commands::ImageCommand if SiteSetting.ai_stability_api_key.present?
            if SiteSetting.ai_google_custom_search_api_key.present? &&
                 SiteSetting.ai_google_custom_search_cx.present?
              cmds << Commands::GoogleCommand
            end

            cmds
          end
      end

      def system_prompt(post, triage:)
        common = <<~TEXT
          You live in the forum with the URL: #{Discourse.base_url}
          The title of your site: #{SiteSetting.title}
          The description is: #{SiteSetting.site_description}
          The participants in this conversation are: #{post.topic.allowed_users.map(&:username).join(", ")}
          The date now is: #{Time.zone.now}, much has changed since you were trained.
        TEXT

        if triage
          <<~TEXT
            You are a decision making bot. Given a conversation you determine which commands will
            complete a task. You are not a chatbot, you do not have a personality.

            YOU only ever reply with !commands, If you have nothing to say, say !noop

            #{common}

            The following !commands are available.

            #{available_commands.map(&:desc).join("\n")}
            !noop: do nothing, you determined there is no special command to run

            Discourse topic paths are /t/slug/topic_id/optional_number

            #{available_commands.map(&:extra_context).compact_blank.join("\n")}

            Commands should be issued in single assistant message.

            Example sessions:

            Human: echo the text 'test'
            Assistant: !echo test
          TEXT
        else
          <<~TEXT
            You are a helpful Discourse assistant, you answer questions and generate Discourse flavoured Markdown.
            You live in a Discourse Forum Message.
            You are provided with the context of previous discussions.

            #{common}
          TEXT
        end
      end

      def tokenize(text)
        raise NotImplemented
      end

      def submit_prompt(prompt, prefer_low_cost: false, &blk)
        raise NotImplemented
      end

      def get_delta(partial, context)
        raise NotImplemented
      end

      protected

      def get_updated_title(prompt)
        raise NotImplemented
      end

      def model_for(bot)
        raise NotImplemented
      end

      def conversation_context(post)
        context =
          post
            .topic
            .posts
            .includes(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .order("post_number desc")
            .where("post_type = ?", Post.types[:regular])
            .limit(50)
            .pluck(:raw, :username, "post_custom_prompts.custom_prompt")

        result = []

        first = true
        context.each do |raw, username, custom_prompt|
          if custom_prompt.present?
            if first
              custom_prompt.reverse_each { |message| result << message }
              first = false
            else
              result << custom_prompt.first
            end
          else
            result << [raw, username]
          end
        end

        result
      end

      def publish_update(bot_reply_post, payload)
        MessageBus.publish(
          "discourse-ai/ai-bot/topic/#{bot_reply_post.topic_id}",
          payload.merge(post_id: bot_reply_post.id, post_number: bot_reply_post.post_number),
          user_ids: bot_reply_post.topic.allowed_user_ids,
        )
      end
    end
  end
end
