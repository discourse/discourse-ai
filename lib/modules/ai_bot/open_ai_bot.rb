# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class OpenAiBot < Bot
      def self.can_reply_as?(bot_user)
        open_ai_bot_ids = [
          DiscourseAi::AiBot::EntryPoint::GPT4_ID,
          DiscourseAi::AiBot::EntryPoint::GPT3_5_TURBO_ID,
        ]

        open_ai_bot_ids.include?(bot_user.id)
      end

      def prompt_limit
        3500
      end

      def reply_params
        { temperature: 0.4, top_p: 0.9, max_tokens: 3000 }
      end

      private

      def build_message(poster_username, content, system: false)
        is_bot = poster_username == bot_user.username

        if system
          role = "system"
        else
          role = is_bot ? "assistant" : "user"
        end

        { role: role, content: is_bot ? content : "#{poster_username}: #{content}" }
      end

      def model_for
        return "gpt-4" if bot_user.id == DiscourseAi::AiBot::EntryPoint::GPT4_ID
        "gpt-3.5-turbo"
      end

      def update_with_delta(current_delta, partial)
        current_delta + partial.dig(:choices, 0, :delta, :content).to_s
      end

      def get_updated_title(prompt)
        DiscourseAi::Inference::OpenAiCompletions.perform!(
          prompt,
          model_for,
          temperature: 0.7,
          top_p: 0.9,
          max_tokens: 40,
        ).dig(:choices, 0, :message, :content)
      end

      def submit_prompt_and_stream_reply(prompt, &blk)
        DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model_for, **reply_params, &blk)
      end

      def tokenize(text)
        DiscourseAi::Tokenizer::OpenAiTokenizer.tokenize(text)
      end
    end
  end
end
