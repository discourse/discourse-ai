# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class ChatThreadTitler
      def initialize(thread)
        @thread = thread
      end

      def thread_content
        # Replace me by a proper API call
        @thread
          .chat_messages
          .joins(:user)
          .pluck(:username, :message)
          .map { |username, message| "#{username}: #{message}" }
          .join("\n")
      end

      def suggested_title
        return nil if thread_content.blank?

        prompt = CompletionPrompt.enabled_by_name(id: "generate_titles")
        raise Discourse::InvalidParameters.new(:mode) if !prompt

        response =
          DiscourseAi::AiHelper::LlmPrompt.new.generate_and_send_prompt(prompt, thread_content)
        response.dig(:suggestions)&.first
      end
    end
  end
end
