# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          @parent_module_name = modules_and_choose_llm_settings.invert[@opts[:name]]

          @parent_enabled = SiteSetting.public_send(@parent_module_name)
          return !@parent_enabled
        end

        run_test(val).tap { |result| @unreachable = result }
      rescue StandardError => e
        raise e if Rails.env.test?
        @unreachable = true
        true
      end

      def run_test(val)
        if Rails.env.test?
          # In test mode, we assume the model is reachable.
          return true
        end

        DiscourseAi::Completions::Llm
          .proxy(val)
          .generate("How much is 1 + 1?", user: nil, feature_name: "llm_validator")
          .present?
      end

      def modules_using(llm_model)
        in_use_llms = AiPersona.where.not(default_llm_id: nil).pluck(:default_llm_id)
        default_llm = SiteSetting.ai_default_llm_model.presence&.to_i

        combined_llms = (in_use_llms + [default_llm]).compact.uniq
        combined_llms
      end

      def error_message
        if @parent_enabled
          return(
            I18n.t(
              "discourse_ai.llm.configuration.disable_module_first",
              setting: @parent_module_name,
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
          ai_embeddings_semantic_search_enabled: :ai_default_llm_model,
          ai_helper_enabled: :ai_default_llm_model,
          ai_summarization_enabled: :ai_default_llm_model,
          ai_translation_enabled: :ai_default_llm_model,
        }
      end
    end
  end
end
