# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class AnthropicBot < Bot
      def self.can_reply_as?(bot_user)
        bot_user.id == DiscourseAi::AiBot::EntryPoint::CLAUDE_V1_ID
      end

      def bot_prompt_with_topic_context(post)
        super(post).join("\n\n")
      end

      def prompt_limit
        7500 # https://console.anthropic.com/docs/prompt-design#what-is-a-prompt
      end

      private

      def build_message(poster_username, content)
        role = poster_username == bot_user.username ? "Assistant" : "Human"

        "#{role}: #{content}"
      end

      def model_for
        "claude-v1"
      end

      def update_with_delta(_, partial)
        partial[:completion]
      end

      def submit_prompt_and_stream_reply(prompt, &blk)
        DiscourseAi::Inference::AnthropicCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.4,
          max_tokens: 3000,
          &blk
        )
      end
    end
  end
end
