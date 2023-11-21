# frozen_string_literal: true

class LocalizedAiPersonaSerializer < ApplicationSerializer
  root "ai_persona"

  attributes :id,
             :name,
             :description,
             :enabled,
             :system,
             :priority,
             :commands,
             :system_prompt,
             :allowed_group_ids

  def name
    object.instance.name
  end

  def description
    object.instance.description
  end
end
