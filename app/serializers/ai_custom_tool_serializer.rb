# frozen_string_literal: true

class AiCustomToolSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :summary,
             :parameters,
             :script,
             :created_by_id,
             :created_at,
             :updated_at

  self.root = "ai_tool"
end
