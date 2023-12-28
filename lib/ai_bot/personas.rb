# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      def self.system_personas
        @system_personas ||= {
          Personas::General => -1,
          Personas::SqlHelper => -2,
          Personas::Artist => -3,
          Personas::SettingsExplorer => -4,
          Personas::Researcher => -5,
          Personas::Creative => -6,
          Personas::DallE3 => -7,
        }
      end

      def self.system_personas_by_id
        @system_personas_by_id ||= system_personas.invert
      end

      def self.all(user:)
        # this needs to be dynamic cause site settings may change
        all_available_tools = Persona.all_available_tools

        AiPersona.all_personas.filter do |persona|
          next false if !user.in_any_groups?(persona.allowed_group_ids)

          if persona.system
            instance = persona.new
            (
              instance.required_tools == [] ||
                (instance.required_tools - all_available_tools).empty?
            )
          else
            true
          end
        end
      end

      def self.find_by(id: nil, name: nil, user:)
        all(user: user).find { |persona| persona.id == id || persona.name == name }
      end
    end
  end
end
