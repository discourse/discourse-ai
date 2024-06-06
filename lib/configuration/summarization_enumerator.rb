# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class SummarizationEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        @values ||=
          DiscourseAi::Summarization::Models::Base.available_strategies.map do |strategy|
            { name: strategy.display_name, value: strategy.model }
          end
      end
    end
  end
end
