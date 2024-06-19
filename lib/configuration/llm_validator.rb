# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          parent_module_name = modules_and_choose_llm_settings.invert[@opts[:name]]

          @parent_enabled = SiteSetting.public_send(parent_module_name)
          return !@parent_enabled
        end

        llm_model_id = val.split(":")&.last
        llm_model = LlmModel.find_by(id: llm_model_id)
        return false if llm_model.nil?

        run_test(llm_model).tap { |result| @unreachable = result }
      rescue StandardError
        @unreachable = true
        false
      end

      def run_test(llm_model)
        DiscourseAi::Completions::Llm
          .proxy_from_obj(llm_model)
          .generate("How much is 1 + 1?", user: nil, feature_name: "llm_validator")
          .present?
      end

      def modules_using(llm_model)
        choose_llm_settings = modules_and_choose_llm_settings.values

        choose_llm_settings.select { |s| SiteSetting.public_send(s) == "custom:#{llm_model.id}" }
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

        return unless @unreachable

        I18n.t("discourse_ai.llm.configuration.model_unreachable")
      end

      def choose_llm_setting_for(module_enabler_setting)
        modules_and_choose_llm_settings[module_enabler_setting]
      end

      def modules_and_choose_llm_settings
        {
          ai_embeddings_semantic_search_enabled: :ai_embeddings_semantic_search_hyde_model,
          composer_ai_helper_enabled: :ai_helper_model,
        }
      end
    end
  end
end
