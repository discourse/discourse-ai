# frozen_string_literal: true

class AiPersonaSerializer < ApplicationSerializer
  attributes :id, :name, :description, :enabled, :system, :priority, :commands, :system_prompt

  def name
    object.instance.name
  end

  def description
    object.instance.description
  end
end
