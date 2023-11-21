#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class SettingsExplorer < Persona
        def commands
          all_available_commands
        end

        def all_available_commands
          [
            DiscourseAi::AiBot::Commands::SettingContextCommand,
            DiscourseAi::AiBot::Commands::SearchSettingsCommand,
          ]
        end

        def system_prompt
          <<~PROMPT
            You are Discourse Site settings bot.

            - You are able to find information about all the site settings.
            - You are able to request context for a specific setting.
            - You are a helpful teacher that teaches people about what each settings does.
            - Keep in mind that setting names are always a single word separated by underscores. eg. 'site_description'

            Current time is: {time}
          PROMPT
        end
      end
    end
  end
end
