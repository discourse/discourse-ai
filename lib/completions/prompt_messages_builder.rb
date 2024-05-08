# frozen_string_literal: true
#
module DiscourseAi
  module Completions
    class PromptMessagesBuilder
      MAX_CHAT_UPLOADS = 5

      def initialize
        @raw_messages = []
      end

      def to_a(limit: nil, style: nil)
        return chat_array(limit: limit) if style == :chat
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
              last_message[:content] = "#{old_name}: #{last_message[:content]}" if old_name

              new_content = message[:content]
              new_content = "#{message[:name]}: #{new_content}" if message[:name]

              last_message[:content] += "\n#{new_content}"
            else
              last_message[:content] = message[:content]
            end
          else
            result << message
          end

          last_type = message[:type]
        end

        if limit
          result[0..limit]
        else
          result
        end
      end

      def push(type:, content:, name: nil, upload_ids: nil, id: nil)
        if !%i[user model tool tool_call system].include?(type)
          raise ArgumentError, "type must be either :user, :model, :tool, :tool_call or :system"
        end
        raise ArgumentError, "upload_ids must be an array" if upload_ids && !upload_ids.is_a?(Array)

        message = { type: type, content: content }
        message[:name] = name.to_s if name
        message[:upload_ids] = upload_ids if upload_ids
        message[:id] = id.to_s if id

        @raw_messages << message
      end

      private

      def chat_array(limit:)
        buffer = +""

        if @raw_messages.length > 1
          buffer << (<<~TEXT).strip
            You are replying inside a Discourse chat. Here is a summary of the conversation so far:
            {{{
          TEXT

          upload_ids = []

          @raw_messages[0..-2].each do |message|
            buffer << "\n"

            upload_ids.concat(message[:upload_ids]) if message[:upload_ids].present?

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
        buffer << "#{last_message[:name] || "User"} said #{last_message[:content]} "

        message = { type: :user, content: buffer }
        upload_ids.concat(last_message[:upload_ids]) if last_message[:upload_ids].present?

        message[:upload_ids] = upload_ids[-MAX_CHAT_UPLOADS..-1] ||
          upload_ids if upload_ids.present?

        [message]
      end
    end
  end
end
