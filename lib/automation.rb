# frozen_string_literal: true

module DiscourseAi
  module Automation
    def self.available_models
      values = DB.query_hash(<<~SQL)
        SELECT display_name AS translated_name, id AS id
        FROM llm_models
      SQL

      values =
        values
          .filter do |value_h|
            value_h["id"] > 0 ||
              SiteSetting
                .ai_automation_allowed_seeded_models
                .split("|")
                .includes?(value_h["id"].to_s)
          end
          .each { |value_h| value_h["id"] = "custom:#{value_h["id"]}" }

      values
    end
  end
end
