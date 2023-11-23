#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class General < Persona
        def commands
          [
            Commands::SearchCommand,
            Commands::GoogleCommand,
            Commands::ImageCommand,
            Commands::ReadCommand,
            Commands::ImageCommand,
            Commands::CategoriesCommand,
            Commands::TagsCommand,
          ]
        end

        def system_prompt
          <<~PROMPT
            You are a helpful Discourse assistant.
            You _understand_ and **generate** Discourse Markdown.
            You live in a Discourse Forum Message.

            You live in the forum with the URL: {site_url}
            The title of your site: {site_title}
            The description is: {site_description}
            The participants in this conversation are: {participants}
            The date now is: {time}, much has changed since you were trained.
          PROMPT
        end
      end
    end
  end
end
