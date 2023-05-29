# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class AnthropicBot < Bot
      def self.can_reply_as?(bot_user)
        bot_user.id == DiscourseAi::AiBot::EntryPoint::CLAUDE_V1_ID
      end

      def bot_prompt_with_topic_context(post, triage: false)
        super(post, triage: triage).join("\n\n")
      end

      def prompt_limit
        7500 # https://console.anthropic.com/docs/prompt-design#what-is-a-prompt
      end

      def get_delta(partial, context)
        context[:pos] ||= 0

        full = partial[:completion]
        delta = full[context[:pos]..-1]

        context[:pos] = full.length
        delta
      end

      private

      def build_message(poster_username, content, system: false, last: false)
        role = poster_username == bot_user.username ? "Assistant" : "Human"

        result = +"#{role}: #{content}"
        result << "\nAssistant: " if last

        result
      end

      def model_for
        "claude-v1"
      end

      def get_updated_title(prompt)
        DiscourseAi::Inference::AnthropicCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.7,
          max_tokens: 40,
        ).dig(:completion)
      end

      def submit_prompt(prompt, max_tokens: nil, temperature: nil, prefer_low_cost: false, &blk)
        DiscourseAi::Inference::AnthropicCompletions.perform!(
          prompt,
          model_for,
          temperature: temperature || 0.4,
          max_tokens: max_tokens || 3000,
          &blk
        )
      end

      def tokenize(text)
        DiscourseAi::Tokenizer::AnthropicTokenizer.tokenize(text)
      end
    end
  end
end
