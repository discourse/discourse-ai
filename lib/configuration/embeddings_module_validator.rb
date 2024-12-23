# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingsModuleValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"
        return true if Rails.env.test?

        chosen_model = SiteSetting.ai_embeddings_model

        return false if !chosen_model

        representation =
          DiscourseAi::Embeddings::VectorRepresentations::Base.find_representation(chosen_model)

        return false if representation.nil?

        if !representation.correctly_configured?
          @representation = representation
          return false
        end

        if !can_generate_embeddings?(chosen_model)
          @unreachable = true
          return false
        end

        true
      end

      def error_message
        return(I18n.t("discourse_ai.embeddings.configuration.model_unreachable")) if @unreachable

        @representation&.configuration_hint
      end

      def can_generate_embeddings?(val)
        DiscourseAi::Embeddings::VectorRepresentations::Base
          .find_representation(val)
          .new
          .inference_client
          .perform!("this is a test")
          .present?
      end
    end
  end
end
