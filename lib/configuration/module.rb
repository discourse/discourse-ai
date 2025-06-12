# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Module
      SUMMARIZATION = "summarization"
      SEARCH = "search"
      DISCORD = "discord"
      INFERENCE = "inference"
      AI_HELPER = "ai_helper"

      NAMES = [SUMMARIZATION, SEARCH, DISCORD, INFERENCE, AI_HELPER]

      SUMMARIZATION_ID = 1
      SEARCH_ID = 2
      DISCORD_ID = 3
      INFERENCE_ID = 4
      AI_HELPER_ID = 5

      class << self
        def all
          [
            new(
              SUMMARIZATION_ID,
              SUMMARIZATION,
              "ai_summarization_enabled",
              features: DiscourseAi::Configuration::Feature.summarization_features,
            ),
            new(
              SEARCH_ID,
              SEARCH,
              "ai_bot_enabled",
              features: DiscourseAi::Configuration::Feature.search_features,
            ),
            new(
              DISCORD_ID,
              DISCORD,
              "ai_discord_search_enabled",
              features: DiscourseAi::Configuration::Feature.discord_features,
            ),
            new(
              INFERENCE_ID,
              INFERENCE,
              "inferred_concepts_enabled",
              features: DiscourseAi::Configuration::Feature.inference_features,
            ),
            new(
              AI_HELPER_ID,
              AI_HELPER,
              "ai_helper_enabled",
              features: DiscourseAi::Configuration::Feature.ai_helper_features,
            ),
          ]
        end

        def find_by(id:)
          all.find { |m| m.id == id }
        end
      end

      def initialize(id, name, enabled_by_setting, features: [])
        @id = id
        @name = name
        @enabled_by_setting = enabled_by_setting
        @features = features
      end

      attr_reader :id, :name, :enabled_by_setting, :features

      def enabled?
        SiteSetting.get(enabled_by_setting)
      end
    end
  end
end
