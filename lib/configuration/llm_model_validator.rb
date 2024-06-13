# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmModelValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        model_names = val.to_s.split("|")
        existing_models = LlmModel.where(name: model_names).pluck(:name)

        @missing_names = model_names - existing_models

        @missing_names.empty?
      end

      def error_message
        I18n.t(
          "discourse_ai.llm.configuration.configure_llm",
          models: @missing_names.join(", "),
          count: @missing_names.length,
        )
      end
    end
  end
end
