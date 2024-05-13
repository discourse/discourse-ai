# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          @parent_enabled = SiteSetting.public_send(parent_module_name)
          return !@parent_enabled
        end

        provider_and_model_name = val.split(":")
        provider_name = provider_and_model_name.first
        model_name_without_prov = provider_and_model_name[1..].join
        is_custom_model = provider_name == "custom"

        if is_custom_model
          llm_model = LlmModel.find(model_name_without_prov)
          provider_name = llm_model.provider
          model_name_without_prov = llm_model.name
        end

        endpoint = DiscourseAi::Completions::Endpoints::Base.endpoint_for(provider_name)

        return false if endpoint.nil?

        if !endpoint.correctly_configured?(model_name_without_prov)
          @endpoint = endpoint
          return false
        end

        if !can_talk_to_model?(val)
          @unreachable = true
          return false
        end

        true
      end

      def error_message
        if @parent_enabled
          return(
            I18n.t(
              "discourse_ai.llm.configuration.disable_module_first",
              setting: parent_module_name,
            )
          )
        end

        return(I18n.t("discourse_ai.llm.configuration.model_unreachable")) if @unreachable

        @endpoint&.configuration_hint
      end

      def parent_module_name
        if @opts[:name] == :ai_embeddings_semantic_search_hyde_model
          :ai_embeddings_semantic_search_enabled
        else
          :composer_ai_helper_enabled
        end
      end

      private

      def can_talk_to_model?(model_name)
        DiscourseAi::Completions::Llm
          .proxy(model_name)
          .generate("How much is 1 + 1?", user: nil)
          .present?
      rescue StandardError
        false
      end
    end
  end
end
