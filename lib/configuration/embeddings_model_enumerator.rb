# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class EmbeddingsModelEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        %w[
          all-mpnet-base-v2
          text-embedding-ada-002
          text-embedding-3-small
          text-embedding-3-large
          multilingual-e5-large
          bge-large-en
          gemini
        ]
      end
    end
  end
end
