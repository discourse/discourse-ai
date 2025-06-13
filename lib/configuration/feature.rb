# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class Feature
      class << self
        def feature_cache
          @feature_cache ||= ::DiscourseAi::MultisiteHash.new("feature_cache")
        end

        def summarization_features
          feature_cache[:summarization] ||= [
            new(
              "topic_summaries",
              "ai_summarization_persona",
              DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
              DiscourseAi::Configuration::Module::SUMMARIZATION,
            ),
            new(
              "gists",
              "ai_summary_gists_persona",
              DiscourseAi::Configuration::Module::SUMMARIZATION_ID,
              DiscourseAi::Configuration::Module::SUMMARIZATION,
              enabled_by_setting: "ai_summary_gists_enabled",
            ),
          ]
        end

        def search_features
          feature_cache[:search] ||= [
            new(
              "discoveries",
              "ai_bot_discover_persona",
              DiscourseAi::Configuration::Module::SEARCH_ID,
              DiscourseAi::Configuration::Module::SEARCH,
            ),
          ]
        end

        def discord_features
          feature_cache[:discord] ||= [
            new(
              "search",
              "ai_discord_search_persona",
              DiscourseAi::Configuration::Module::DISCORD_ID,
              DiscourseAi::Configuration::Module::DISCORD,
            ),
          ]
        end

        def inference_features
          feature_cache[:inference] ||= [
            new(
              "generate_concepts",
              "inferred_concepts_generate_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "match_concepts",
              "inferred_concepts_match_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
            new(
              "deduplicate_concepts",
              "inferred_concepts_deduplicate_persona",
              DiscourseAi::Configuration::Module::INFERENCE_ID,
              DiscourseAi::Configuration::Module::INFERENCE,
            ),
          ]
        end

        def ai_helper_features
          feature_cache[:ai_helper] ||= [
            new(
              "proofread",
              "ai_helper_proofreader_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "title_suggestions",
              "ai_helper_title_suggestions_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "explain",
              "ai_helper_explain_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "smart_dates",
              "ai_helper_smart_dates_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "markdown_tables",
              "ai_helper_markdown_tables_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "custom_prompt",
              "ai_helper_custom_prompt_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
            new(
              "image_caption",
              "ai_helper_image_caption_persona",
              DiscourseAi::Configuration::Module::AI_HELPER_ID,
              DiscourseAi::Configuration::Module::AI_HELPER,
            ),
          ]
        end

        def translation_features
          feature_cache[:translation] ||= [
            new(
              "locale_detector",
              "ai_translation_locale_detector_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "post_raw_translator",
              "ai_translation_post_raw_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "topic_title_translator",
              "ai_translation_topic_title_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
            new(
              "short_text_translator",
              "ai_translation_short_text_translator_persona",
              DiscourseAi::Configuration::Module::TRANSLATION_ID,
              DiscourseAi::Configuration::Module::TRANSLATION,
            ),
          ]
        end

        def all
          [
            summarization_features,
            search_features,
            discord_features,
            inference_features,
            ai_helper_features,
            translation_features,
          ].flatten
        end

        def all_persona_setting_names
          all.map(&:persona_setting)
        end

        def find_features_using(persona_id:)
          all.select { |feature| feature.persona_id == persona_id }
        end
      end

      def initialize(name, persona_setting, module_id, module_name, enabled_by_setting: "")
        @name = name
        @persona_setting = persona_setting
        @module_id = module_id
        @module_name = module_name
        @enabled_by_setting = enabled_by_setting
      end

      attr_reader :name, :persona_setting, :module_id, :module_name

      def enabled?
        @enabled_by_setting.blank? || SiteSetting.get(@enabled_by_setting)
      end

      def persona_id
        SiteSetting.get(persona_setting).to_i
      end
    end
  end
end
