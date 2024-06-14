# frozen_string_literal: true

module DiscourseAi
  module Summarization
    class EntryPoint
      def inject_into(plugin)
        DiscoursePluginRegistry.define_filtered_register :summarization_strategies

        plugin.add_to_serializer(:current_user, :can_summarize) do
          scope.user.in_any_groups?(SiteSetting.ai_custom_summarization_allowed_groups_map)
        end

        plugin.add_to_serializer(:topic_view, :summarizable) do
          DiscourseAi::Summarization::Models::Base.can_see_summary?(object.topic, scope.user)
        end

        plugin.add_to_serializer(:web_hook_topic_view, :summarizable) do
          DiscourseAi::Summarization::Models::Base.can_see_summary?(object.topic, scope.user)
        end

        foldable_models = [
          Models::OpenAi.new("open_ai:gpt-4", max_tokens: 8192),
          Models::OpenAi.new("open_ai:gpt-4-32k", max_tokens: 32_768),
          Models::OpenAi.new("open_ai:gpt-4-turbo", max_tokens: 100_000),
          Models::OpenAi.new("open_ai:gpt-4o", max_tokens: 100_000),
          Models::OpenAi.new("open_ai:gpt-3.5-turbo", max_tokens: 4096),
          Models::OpenAi.new("open_ai:gpt-3.5-turbo-16k", max_tokens: 16_384),
          Models::Gemini.new("google:gemini-pro", max_tokens: 32_768),
          Models::Gemini.new("google:gemini-1.5-pro", max_tokens: 800_000),
          Models::Gemini.new("google:gemini-1.5-flash", max_tokens: 800_000),
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
        foldable_models << Models::Anthropic.new(
          "#{claude_prov}:claude-3-haiku",
          max_tokens: 200_000,
        )
        foldable_models << Models::Anthropic.new(
          "#{claude_prov}:claude-3-sonnet",
          max_tokens: 200_000,
        )

        foldable_models << Models::Anthropic.new(
          "#{claude_prov}:claude-3-opus",
          max_tokens: 200_000,
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

        # TODO: Roman, we need to de-register custom LLMs on destroy from summarization
        # strategy and clear cache
        # it may be better to pull all of this code into Discourse AI cause as it stands
        # the coupling is making it really hard to reason about summarization
        #
        # Auto registration and de-registration needs to be tested

        #LlmModel.all.each do |model|
        #  foldable_models << Models::CustomLlm.new(
        #    "custom:#{model.id}",
        #    max_tokens: model.max_prompt_tokens,
        #  )
        #end

        foldable_models.each do |model|
          DiscoursePluginRegistry.register_summarization_strategy(
            Strategies::FoldContent.new(model),
            Plugin::Instance.new,
          )
        end

        #plugin.add_model_callback(LlmModel, :after_create) do
        #  new_model = Models::CustomLlm.new("custom:#{self.id}", max_tokens: self.max_prompt_tokens)

        #  if ::Summarization::Base.find_strategy("custom:#{self.id}").nil?
        #    plugin.register_summarization_strategy(Strategies::FoldContent.new(new_model))
        #  end
        #end
      end
    end
  end
end
