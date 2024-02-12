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
             :top_p,
             :mentionable,
             :default_llm,
             :user_id

  has_one :user, serializer: BasicUserSerializer, embed: :object

  def name
    object.class_instance.name
  end

  def description
    object.class_instance.description
  end
end
