# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class ChatThreadTitler
      def initialize(thread)
        @thread = thread
      end

      def suggested_title
        return nil if thread_content.blank?

        prompt = CompletionPrompt.enabled_by_name("generate_titles")
        raise Discourse::InvalidParameters.new(:mode) if !prompt

        response =
          DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
            prompt,
            thread_content,
            thread.original_message_user,
          )
        response.dig(:suggestions)&.first
      end

      private

      attr_reader :thread

      def thread_content
        # Replace me by a proper API call
        thread
          .chat_messages
          .joins(:user)
          .pluck(:username, :message)
          .map { |username, message| "#{username}: #{message}" }
          .join("\n")
      end
    end
  end
end
