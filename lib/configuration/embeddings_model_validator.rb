# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingsModelValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          @embeddings_enabled = SiteSetting.ai_embeddings_enabled
          return !@embeddings_enabled
        end

        representation =
          DiscourseAi::Embeddings::VectorRepresentations::Base.find_representation(val)

        return false if representation.nil?

        # Skip config for tests. We stub embeddings generation anyway.
        return true if Rails.env.test? && val

        if !representation.correctly_configured?
          @representation = representation
          return false
        end

        if !can_generate_embeddings?(val)
          @unreachable = true
          return false
        end

        true
      end

      def error_message
        if @embeddings_enabled
          return(I18n.t("discourse_ai.embeddings.configuration.disable_embeddings"))
        end

        return(I18n.t("discourse_ai.embeddings.configuration.model_unreachable")) if @unreachable

        @representation&.configuration_hint
      end

      def can_generate_embeddings?(val)
        DiscourseAi::Embeddings::VectorRepresentations::Base
          .find_representation(val)
          .new(DiscourseAi::Embeddings::Strategies::Truncation.new)
          .vector_from("this is a test")
          .present?
      end
    end
  end
end
