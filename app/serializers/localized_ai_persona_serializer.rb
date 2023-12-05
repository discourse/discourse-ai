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
             :command_options,
             :system_prompt,
             :allowed_group_ids

  def commands
    object.commands.map { |command| command.is_a?(Array) ? command[0] : command }
  end

  def command_options
    options = {}
    object.commands.each do |command, local_options|
      options[command] = local_options if local_options
    end
    options
  end

  def name
    object.class_instance.name
  end

  def description
    object.class_instance.description
  end
end
