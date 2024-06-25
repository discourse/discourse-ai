# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmDependencyValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"

        @llm_dependency_setting_name =
          DiscourseAi::Configuration::LlmValidator.new.choose_llm_setting_for(@opts[:name])

        SiteSetting.public_send(@llm_dependency_setting_name).present?
      end

      def error_message
        I18n.t(
          "discourse_ai.llm.configuration.set_llm_first",
          setting: @llm_dependency_setting_name,
        )
      end
    end
  end
end
