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
             :allowed_group_ids,
             :temperature,
             :top_p

  def name
    object.class_instance.name
  end

  def description
    object.class_instance.description
  end
end
