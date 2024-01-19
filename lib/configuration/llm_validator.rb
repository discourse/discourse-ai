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

        endpoint =
          DiscourseAi::Completions::Endpoints::Base.endpoint_for(
            provider_name,
            model_name_without_prov,
          )

        return false if endpoint.nil?

        endpoint
          .correctly_configured?(model_name_without_prov)
          .tap { |is_valid| @endpoint = endpoint if !is_valid }
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

        @endpoint.configuration_hint
      end

      def parent_module_name
        if @opts[:name] == :ai_embeddings_semantic_search_hyde_model
          :ai_embeddings_semantic_search_enabled
        else
          :composer_ai_helper_enabled
        end
      end
    end
  end
end
