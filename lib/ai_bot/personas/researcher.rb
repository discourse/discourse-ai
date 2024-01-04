#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Researcher < Persona
        def tools
          [Tools::Google]
        end

        def required_tools
          [Tools::Google]
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
