# frozen_string_literal: true

module DiscourseAi
  module Features
    def self.features_config
      [
        {
          id: 1,
          module_name: "summarization",
          module_enabled: "ai_summarization_enabled",
          features: [
            { name: "topic_summaries", persona_setting_name: "ai_summarization_persona" },
            {
              name: "gists",
              persona_setting_name: "ai_summary_gists_persona",
              enabled: "ai_summary_gists_enabled",
            },
          ],
        },
        {
          id: 2,
          module_name: "search",
          module_enabled: "ai_bot_enabled",
          features: [{ name: "discoveries", persona_setting_name: "ai_bot_discover_persona" }],
        },
        {
          id: 3,
          module_name: "discord",
          module_enabled: "ai_discord_search_enabled",
          features: [{ name: "search", persona_setting_name: "ai_discord_search_persona" }],
        },
        {
          id: 4,
          module_name: "inference",
          module_enabled: "inferred_concepts_enabled",
          features: [
            {
              name: "generate_concepts",
              persona_setting_name: "inferred_concepts_generate_persona",
            },
            { name: "match_concepts", persona_setting_name: "inferred_concepts_match_persona" },
            {
              name: "deduplicate_concepts",
              persona_setting_name: "inferred_concepts_deduplicate_persona",
            },
          ],
        },
        {
          id: 5,
          module_name: "ai_helper",
          module_enabled: "ai_helper_enabled",
          features: [
            { name: "proofread", persona_setting_name: "ai_helper_proofreader_persona" },
            {
              name: "title_suggestions",
              persona_setting_name: "ai_helper_title_suggestions_persona",
            },
            { name: "explain", persona_setting_name: "ai_helper_explain_persona" },
            { name: "illustrate_post", persona_setting_name: "ai_helper_post_illustrator_persona" },
            { name: "smart_dates", persona_setting_name: "ai_helper_smart_dates_persona" },
            { name: "translate", persona_setting_name: "ai_helper_translator_persona" },
            { name: "markdown_tables", persona_setting_name: "ai_helper_markdown_tables_persona" },
            { name: "custom_prompt", persona_setting_name: "ai_helper_custom_prompt_persona" },
            { name: "image_caption", persona_setting_name: "ai_helper_image_caption_persona" },
          ],
        },
      ]
    end

    def self.features
      features_config.map do |a_module|
        {
          id: a_module[:id],
          module_name: a_module[:module_name],
          module_enabled: SiteSetting.get(a_module[:module_enabled]),
          features:
            a_module[:features].map do |feature|
              {
                name: feature[:name],
                persona: AiPersona.find_by(id: SiteSetting.get(feature[:persona_setting_name])),
                enabled: feature[:enabled].present? ? SiteSetting.get(feature[:enabled]) : true,
              }
            end,
        }
      end
    end

    def self.find_module_by_id(id)
      lookup = features.index_by { |f| f[:id] }
      lookup[id]
    end

    def self.find_module_by_name(module_name)
      lookup = features.index_by { |f| f[:module] }
      lookup[module_name]
    end

    def self.find_module_id_by_name(module_name)
      find_module_by_name(module_name)&.dig(:id)
    end

    def self.feature_area(module_name)
      name_s = module_name.to_s
      find_module_by_name(name_s) || raise(ArgumentError, "Feature not found: #{name_s}")
      "ai-features/#{name_s}"
    end
  end
end
