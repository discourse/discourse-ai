# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class AnthropicBot < Bot
      def self.can_reply_as?(bot_user)
        bot_user.id == DiscourseAi::AiBot::EntryPoint::CLAUDE_V2_ID
      end

      def bot_prompt_with_topic_context(post)
        super(post).join("\n\n") + "\n\nAssistant:"
      end

      def prompt_limit
        50_000 # https://console.anthropic.com/docs/prompt-design#what-is-a-prompt
      end

      def title_prompt(post)
        super(post).join("\n\n") + "\n\nAssistant:"
      end

      def get_delta(partial, context)
        completion = partial[:completion]
        if completion&.start_with?(" ") && !context[:processed_first]
          completion = completion[1..-1]
          context[:processed_first] = true
        end
        completion
      end

      private

      def build_message(poster_username, content, system: false, function: nil)
        role = poster_username == bot_user.username ? "Assistant" : "Human"

        "#{role}: #{content}"
      end

      def model_for
        "claude-2"
      end

      def get_updated_title(prompt)
        DiscourseAi::Inference::AnthropicCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.4,
          max_tokens: 40,
        ).dig(:completion)
      end

      def submit_prompt(prompt, prefer_low_cost: false, &blk)
        DiscourseAi::Inference::AnthropicCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.4,
          max_tokens: 3000,
          &blk
        )
      end

      def tokenizer
        DiscourseAi::Tokenizer::AnthropicTokenizer
      end
    end
  end
end
