# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def inject_into(plugin)
        foldable_models = [
          Models::OpenAi.new("open_ai:gpt-4", max_tokens: 8192),
          Models::OpenAi.new("open_ai:gpt-4-32k", max_tokens: 32_768),
          Models::OpenAi.new("open_ai:gpt-4-0125-preview", max_tokens: 100_000),
          Models::OpenAi.new("open_ai:gpt-3.5-turbo", max_tokens: 4096),
          Models::OpenAi.new("open_ai:gpt-3.5-turbo-16k", max_tokens: 16_384),
          Models::Llama2.new(
            "hugging_face:Llama2-chat-hf",
            max_tokens: SiteSetting.ai_hugging_face_token_limit,
          ),
          Models::Llama2FineTunedOrcaStyle.new(
            "hugging_face:StableBeluga2",
            max_tokens: SiteSetting.ai_hugging_face_token_limit,
          ),
          Models::Gemini.new("google:gemini-pro", max_tokens: 32_768),
        ]

        claude_prov = "anthropic"
        if DiscourseAi::Completions::Endpoints::AwsBedrock.correctly_configured?("claude-2")
          claude_prov = "aws_bedrock"
        end

        foldable_models << Models::Anthropic.new("#{claude_prov}:claude-2", max_tokens: 200_000)
        foldable_models << Models::Anthropic.new(
          "#{claude_prov}:claude-instant-1",
          max_tokens: 100_000,
        )

        mixtral_prov = "hugging_face"
        if DiscourseAi::Completions::Endpoints::Vllm.correctly_configured?(
             "mistralai/Mixtral-8x7B-Instruct-v0.1",
           )
          mixtral_prov = "vllm"
        end

        foldable_models << Models::Mixtral.new(
          "#{mixtral_prov}:mistralai/Mixtral-8x7B-Instruct-v0.1",
          max_tokens: 32_000,
        )

        foldable_models.each do |model|
          plugin.register_summarization_strategy(Strategies::FoldContent.new(model))
        end

        truncatable_models = [
          Models::Discourse.new("long-t5-tglobal-base-16384-book-summary", max_tokens: 16_384),
          Models::Discourse.new("bart-large-cnn-samsum", max_tokens: 1024),
          Models::Discourse.new("flan-t5-base-samsum", max_tokens: 512),
        ]

        truncatable_models.each do |model|
          plugin.register_summarization_strategy(Strategies::TruncateContent.new(model))
        end
      end
    end
  end
end
