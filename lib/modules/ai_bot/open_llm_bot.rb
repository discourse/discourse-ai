# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class OpenLlmBot < Bot
      # format of thebloke chat models is:
      # [INST] <<SYS>> sys message <</SYS>> {prompt} [/INST] {model_reply} [INST] {prompt} [/INST]

      def self.can_reply_as?(bot_user)
        bot_user.id == DiscourseAi::AiBot::EntryPoint::OPEN_LLM_ID
      end

      def bot_prompt_with_topic_context(post)
        messages = super(post)

        # start with system
        result = +""
        result << "<s>[INST] <<SYS>>\n #{messages.shift[:content]} <</SYS>>\n\n #{messages.shift[:content]} [/INST]"

        messages.each do |message|
          if message[:bot]
            result << message[:content]
          else
            result << "</s><s>[INST]#{message[:bot] ? "" : message[:username] + ":"} #{message[:content]} [/INST]"
          end
        end

        result
      end

      def prompt_limit
        2000
      end

      def title_prompt(post)
        super(post).join("\n\n") + "\n\nAssistant:"
      end

      def get_delta(partial, context)
        partial.dig(:token, :text) || ""
      end

      private

      def build_message(poster_username, content, system: false, function: nil)
        { bot: poster_username == bot_user.username, username: poster_username, content: content }
      end

      def model_for
        # we only support single model hosting for huggingface api for now
        "random-string-for-now"
      end

      def get_updated_title(prompt)
        DiscourseAi::Inference::HuggingFaceTextGeneration.perform!(
          prompt,
          model_for,
          temperature: 0.7,
          max_tokens: 40,
        ).dig(:completion)
      end

      def submit_prompt(prompt, prefer_low_cost: false, &blk)
        DiscourseAi::Inference::HuggingFaceTextGeneration.perform!(
          prompt,
          model_for,
          temperature: 0.4,
          max_tokens: 1000,
          &blk
        )
      end

      def tokenize(text)
        DiscourseAi::Tokenizer::AnthropicTokenizer.tokenize(text)
      end
    end
  end
end
