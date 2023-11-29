#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Persona
        def self.name
          I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.name")
        end

        def self.description
          I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.description")
        end

        def commands
          []
        end

        def required_commands
          []
        end

        def render_commands(render_function_instructions:)
          return +"" if available_commands.empty?

          result = +""
          if render_function_instructions
            result << "\n"
            result << function_list.system_prompt
            result << "\n"
          end
          result << available_commands.map(&:custom_system_message).compact.join("\n")
          result
        end

        def render_system_prompt(
          topic: nil,
          render_function_instructions: true,
          allow_commands: true
        )
          substitutions = {
            site_url: Discourse.base_url,
            site_title: SiteSetting.title,
            site_description: SiteSetting.site_description,
            time: Time.zone.now,
          }

          substitutions[:participants] = topic.allowed_users.map(&:username).join(", ") if topic

          prompt =
            system_prompt.gsub(/\{(\w+)\}/) do |match|
              found = substitutions[match[1..-2].to_sym]
              found.nil? ? match : found.to_s
            end

          if allow_commands
            prompt += render_commands(render_function_instructions: render_function_instructions)
          end

          prompt
        end

        def available_commands
          return @available_commands if @available_commands
          @available_commands = all_available_commands.filter { |cmd| commands.include?(cmd) }
        end

        def available_functions
          # note if defined? can be a problem in test
          # this can never be nil so it is safe
          return @available_functions if @available_functions

          functions = []

          functions =
            available_commands.map do |command|
              function =
                DiscourseAi::Inference::Function.new(name: command.name, description: command.desc)
              command.parameters.each { |parameter| function.add_parameter(parameter) }
              function
            end

          @available_functions = functions
        end

        def function_list
          return @function_list if @function_list

          @function_list = DiscourseAi::Inference::FunctionList.new
          available_functions.each { |function| @function_list << function }
          @function_list
        end

        def self.all_available_commands
          all_commands = [
            Commands::CategoriesCommand,
            Commands::TimeCommand,
            Commands::SearchCommand,
            Commands::SummarizeCommand,
            Commands::ReadCommand,
            Commands::DbSchemaCommand,
            Commands::SearchSettingsCommand,
            Commands::SummarizeCommand,
            Commands::SettingContextCommand,
          ]

          all_commands << Commands::TagsCommand if SiteSetting.tagging_enabled
          all_commands << Commands::ImageCommand if SiteSetting.ai_stability_api_key.present?

          all_commands << Commands::DallECommand if SiteSetting.ai_openai_api_key.present?
          if SiteSetting.ai_google_custom_search_api_key.present? &&
               SiteSetting.ai_google_custom_search_cx.present?
            all_commands << Commands::GoogleCommand
          end

          all_commands
        end

        def all_available_commands
          @cmds ||= self.class.all_available_commands
        end
      end
    end
  end
end
