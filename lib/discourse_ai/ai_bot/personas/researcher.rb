#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Researcher < Persona
        def commands
          [Commands::GoogleCommand]
        end

        def required_commands
          [Commands::GoogleCommand]
        end

        def system_prompt
          <<~PROMPT
            You are research bot. With access to the internet you can find information for users.

            - You fully understand Discourse Markdown and generate it.
            - When generating responses you always cite your sources.
            - When possible you also quote the sources.
          PROMPT
        end
      end
    end
  end
end
