# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class LlmEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        values = DB.query_hash(<<~SQL).map(&:symbolize_keys)
          SELECT display_name AS name, id AS value
          FROM llm_models
        SQL

        values.each { |value_h| value_h[:value] = "custom:#{value_h[:value]}" }

        values
      end

      # TODO(roman): Deprecated. Remove by Sept 2024
      def self.old_summarization_options
        %w[
          gpt-4
          gpt-4-32k
          gpt-4-turbo
          gpt-4o
          gpt-3.5-turbo
          gpt-3.5-turbo-16k
          gemini-pro
          gemini-1.5-pro
          gemini-1.5-flash
          claude-2
          claude-instant-1
          claude-3-haiku
          claude-3-sonnet
          claude-3-opus
          mistralai/Mixtral-8x7B-Instruct-v0.1
          mistralai/Mixtral-8x7B-Instruct-v0.1
        ]
      end

      # TODO(roman): Deprecated. Remove by Sept 2024
      def self.available_ai_bots
        %w[
          gpt-3.5-turbo
          gpt-4
          gpt-4-turbo
          gpt-4o
          claude-2
          gemini-1.5-pro
          mixtral-8x7B-Instruct-V0.1
          claude-3-opus
          claude-3-sonnet
          claude-3-haiku
          cohere-command-r-plus
        ]
      end
    end
  end
end
