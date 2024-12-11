# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class LlmEnumerator < ::EnumSiteSetting
      def self.global_usage
        rval = Hash.new { |h, k| h[k] = [] }

        if SiteSetting.ai_bot_enabled
          LlmModel
            .where("enabled_chat_bot = ?", true)
            .pluck(:id)
            .each { |llm_id| rval[llm_id] << { type: :ai_bot } }

          AiPersona
            .where("force_default_llm = ?", true)
            .pluck(:default_llm, :name, :id)
            .each do |llm_name, name, id|
              llm_id = llm_name.split(":").last.to_i
              rval[llm_id] << { type: :ai_persona, name: name, id: id }
            end
        end

        if SiteSetting.ai_helper_enabled
          model_id = SiteSetting.ai_helper_model.split(":").last.to_i
          rval[model_id] << { type: :ai_helper }
        end

        if SiteSetting.ai_summarization_enabled
          model_id = SiteSetting.ai_summarization_model.split(":").last.to_i
          rval[model_id] << { type: :ai_summarization }
        end

        if SiteSetting.ai_embeddings_semantic_search_enabled
          model_id = SiteSetting.ai_embeddings_semantic_search_hyde_model.split(":").last.to_i
          rval[model_id] << { type: :ai_embeddings_semantic_search }
        end

        if SiteSetting.ai_spam_detection_enabled
          model_id = AiModerationSetting.spam[:llm_model_id]
          rval[model_id] << { type: :ai_spam }
        end

        rval
      end

      def self.valid_value?(val)
        true
      end

      def self.values(allowed_seeded_llms: nil)
        values = DB.query_hash(<<~SQL).map(&:symbolize_keys)
          SELECT display_name AS name, id AS value
          FROM llm_models
        SQL

        if allowed_seeded_llms.is_a?(Array)
          values = values.filter do |value_h|
            value_h[:value] > 0 || allowed_seeded_llms.include?("custom:#{value_h[:value]}")
          end
        end

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
