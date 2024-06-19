# frozen_string_literal: true

module DiscourseAi
  module Automation
    def self.available_models
      values = DB.query_hash(<<~SQL)
        SELECT display_name AS translated_name, id AS id
        FROM llm_models
      SQL

      values.each { |value_h| value_h["id"] = "custom:#{value_h["id"]}" }

      values
    end
  end
end
