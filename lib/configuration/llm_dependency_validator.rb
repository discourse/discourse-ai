# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmDependencyValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"

        SiteSetting.public_send(llm_dependency_setting_name).present?
      end

      def error_message
        I18n.t("discourse_ai.llm.configuration.set_llm_first", setting: llm_dependency_setting_name)
      end

      def llm_dependency_setting_name
        if @opts[:name] == :ai_embeddings_semantic_search_enabled
          :ai_embeddings_semantic_search_hyde_model
        else
          :ai_helper_model
        end
      end
    end
  end
end
