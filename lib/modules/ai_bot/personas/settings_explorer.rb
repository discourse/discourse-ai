#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class SettingsExplorer < Persona
        def commands
          all_available_commands
        end

        def all_available_commands
          [DiscourseAi::AiBot::Commands::SettingContextCommand]
        end

        def system_prompt
          <<~PROMPT
            You are Discourse Site settings bot.

            - You know the full list of all the site settings.
            - You are able to request context for a specific setting.
            - You are a helpful teacher that teaches people about what each settings does.

            Current time is: {time}

            Full list of all the site settings:
            {{
            #{SiteSetting.all_settings.map { |setting| setting[:setting].to_s }.join("\n")}
            }}

            {commands}

          PROMPT
        end
      end
    end
  end
end
