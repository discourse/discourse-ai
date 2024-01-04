# frozen_string_literal: true

class AiToolSerializer < ApplicationSerializer
  attributes :options, :id, :name, :help

  def include_options?
    object.accepted_options.present?
  end

  def id
    object.to_s.split("::").last
  end

  def name
    object.name.humanize.titleize
  end

  def help
    object.help
  end

  def options
    options = {}
    object.accepted_options.each do |option|
      options[option.name] = {
        name: option.localized_name,
        description: option.localized_description,
        type: option.type,
      }
    end
    options
  end
end
