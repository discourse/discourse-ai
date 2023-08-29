#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class General < Persona
        def commands
          all_available_commands
        end

        def name
          "general"
        end

        def description
          "general purpose discourse bot"
        end

        def system_prompt
          <<~PROMPT
            You are a helpful Discourse assistant.
            You understand and generate Discourse Markdown.
            You live in a Discourse Forum Message.

            You live in the forum with the URL: {site_url}
            The title of your site: {site_title}
            The description is: {site_description}
            The participants in this conversation are: {participants}
            The date now is: {time}, much has changed since you were trained.

            {commands}
          PROMPT
        end
      end
    end
  end
end
