# frozen_string_literal: true

module DiscourseAi
  module Automation
    def self.flag_types
      [
        { id: "review", translated_name: I18n.t("discourse_automation.ai.flag_types.review") },
        { id: "spam", translated_name: I18n.t("discourse_automation.ai.flag_types.spam") },
        {
          id: "spam_silence",
          translated_name: I18n.t("discourse_automation.ai.flag_types.spam_silence"),
        },
      ]
    end
    def self.available_models
      values = DB.query_hash(<<~SQL)
        SELECT display_name AS translated_name, id AS id
        FROM llm_models
      SQL

      values =
        values
          .filter do |value_h|
            value_h["id"] > 0 ||
              SiteSetting.ai_automation_allowed_seeded_models_map.include?(value_h["id"].to_s)
          end
          .each { |value_h| value_h["id"] = "custom:#{value_h["id"]}" }

      values
    end
  end
end
