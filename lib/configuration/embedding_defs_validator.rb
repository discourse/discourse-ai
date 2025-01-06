# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class EmbeddingDefsValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        val.blank? || EmbeddingDefinition.exists?(id: val)
      end

      def error_message
        ""
      end
    end
  end
end
