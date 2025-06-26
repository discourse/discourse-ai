# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Module
      SUMMARIZATION = "summarization"
      SEARCH = "search"
      DISCORD = "discord"
      INFERENCE = "inference"
      AI_HELPER = "ai_helper"
      TRANSLATION = "translation"
      BOT = "bot"

      NAMES = [SUMMARIZATION, SEARCH, DISCORD, INFERENCE, AI_HELPER, TRANSLATION, BOT].freeze

      SUMMARIZATION_ID = 1
      SEARCH_ID = 2
      DISCORD_ID = 3
      INFERENCE_ID = 4
      AI_HELPER_ID = 5
      TRANSLATION_ID = 6
      BOT_ID = 7

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
              extra_check: -> { SiteSetting.ai_bot_discover_persona.present? },
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
            new(
              TRANSLATION_ID,
              TRANSLATION,
              "ai_translation_enabled",
              features: DiscourseAi::Configuration::Feature.translation_features,
            ),
            new(
              BOT_ID,
              BOT,
              "ai_bot_enabled",
              features: DiscourseAi::Configuration::Feature.bot_features,
            ),
          ]
        end

        def find_by(id:)
          all.find { |m| m.id == id }
        end
      end

      def initialize(id, name, enabled_by_setting, features: [], extra_check: nil)
        @id = id
        @name = name
        @enabled_by_setting = enabled_by_setting
        @features = features
        @extra_check = extra_check
      end

      attr_reader :id, :name, :enabled_by_setting, :features

      def enabled?
        enabled_setting = SiteSetting.get(enabled_by_setting)

        if @extra_check
          enabled_setting && @extra_check.call
        else
          enabled_setting
        end
      end
    end
  end
end
