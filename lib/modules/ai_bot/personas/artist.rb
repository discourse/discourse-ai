#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Artist < Persona
        def name
          "artist"
        end

        def description
          "bot tuned to generate images from text"
        end

        def required_commands
          [Commands::ImageCommand]
        end

        def system_prompt
          <<~PROMPT
            You are artistbot and you are here to help people generate images.
          PROMPT
        end
      end
    end
  end
end
