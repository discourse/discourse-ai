#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      def self.all
        personas = [Personas::General, Personas::SqlHelper]
        personas << Personas::Artist if SiteSetting.ai_stability_api_key.present?
        personas << Personas::SettingsExplorer
        personas << Personas::Researcher if SiteSetting.ai_google_custom_search_api_key.present?

        personas_allowed = SiteSetting.ai_bot_enabled_personas.split("|")
        personas.filter { |persona| personas_allowed.include?(persona.to_s.demodulize.underscore) }
      end

      class Persona
        def self.name
          I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.name")
        end

        def self.description
          I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.description")
        end

        def initialize(allow_commands: true)
          @allow_commands = allow_commands
        end

        def commands
          []
        end

        def render_commands(render_function_instructions:)
          return +"" if !@allow_commands

          result = +""
          if render_function_instructions
            result << "\n"
            result << function_list.system_prompt
            result << "\n"
          end
          result << available_commands.map(&:custom_system_message).compact.join("\n")
          result
        end

        def render_system_prompt(topic: nil, render_function_instructions: true)
          substitutions = {
            site_url: Discourse.base_url,
            site_title: SiteSetting.title,
            site_description: SiteSetting.site_description,
            time: Time.zone.now,
            commands: render_commands(render_function_instructions: render_function_instructions),
          }

          substitutions[:participants] = topic.allowed_users.map(&:username).join(", ") if topic

          system_prompt.gsub(/\{(\w+)\}/) do |match|
            found = substitutions[match[1..-2].to_sym]
            found.nil? ? match : found.to_s
          end
        end

        def available_commands
          return [] if !@allow_commands

          return @available_commands if @available_commands

          @available_commands = all_available_commands.filter { |cmd| commands.include?(cmd) }
        end

        def available_functions
          return [] if !@allow_commands
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

        def all_available_commands
          return @cmds if @cmds

          all_commands = [
            Commands::CategoriesCommand,
            Commands::TimeCommand,
            Commands::SearchCommand,
            Commands::SummarizeCommand,
            Commands::ReadCommand,
          ]

          all_commands << Commands::TagsCommand if SiteSetting.tagging_enabled
          all_commands << Commands::ImageCommand if SiteSetting.ai_stability_api_key.present?
          if SiteSetting.ai_google_custom_search_api_key.present? &&
               SiteSetting.ai_google_custom_search_cx.present?
            all_commands << Commands::GoogleCommand
          end

          allowed_commands = SiteSetting.ai_bot_enabled_chat_commands.split("|")
          @cmds = all_commands.filter { |klass| allowed_commands.include?(klass.name) }
        end
      end
    end
  end
end
