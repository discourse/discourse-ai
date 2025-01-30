# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingDefsValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val.blank?
          @module_enabled = SiteSetting.ai_embeddings_enabled

          !@module_enabled
        else
          EmbeddingDefinition.exists?(id: val).tap { |def_exists| @invalid_option = !def_exists }
        end
      end

      def error_message
        return I18n.t("discourse_ai.embeddings.configuration.disable_embeddings") if @module_enabled
        return I18n.t("discourse_ai.embeddings.configuration.invalid_config") if @invalid_option

        ""
      end
    end
  end
end
