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
      end

      def suggested_title
        input_hash = { text: thread_content }

        llm_prompt =
          DiscourseAi::AiHelper::LlmPrompt
            .new
            .available_prompts(name_filter: "generate_titles")
            .first
        prompt = CompletionPrompt.find_by(id: llm_prompt[:id])
        raise Discourse::InvalidParameters.new(:mode) if !prompt || !prompt.enabled?

        response = DiscourseAi::AiHelper::LlmPrompt.new.generate_and_send_prompt(prompt, input_hash)
        response.dig(:suggestions).first
      end
    end
  end
end
