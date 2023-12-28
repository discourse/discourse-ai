#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Personas
      class Persona
        class << self
          def name
            I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.name")
          end

          def description
            I18n.t("discourse_ai.ai_bot.personas.#{to_s.demodulize.underscore}.description")
          end

          def all_available_tools
            tools = [
              Tools::ListCategories,
              Tools::Time,
              Tools::Search,
              Tools::Summarize,
              Tools::Read,
              Tools::DbSchema,
              Tools::SearchSettings,
              Tools::Summarize,
              Tools::SettingContext,
            ]

            tools << Tools::ListTags if SiteSetting.tagging_enabled
            tools << Tools::Image if SiteSetting.ai_stability_api_key.present?

            tools << Tools::DallE if SiteSetting.ai_openai_api_key.present?
            if SiteSetting.ai_google_custom_search_api_key.present? &&
                 SiteSetting.ai_google_custom_search_cx.present?
              tools << Tools::Google
            end

            tools
          end
        end

        def tools
          []
        end

        def required_tools
          []
        end

        def options
          {}
        end

        def available_tools
          self.class.all_available_tools.filter { |tool| tools.include?(tool) }
        end

        def craft_prompt(context)
          system_insts =
            system_prompt.gsub(/\{(\w+)\}/) do |match|
              found = context[match[1..-2].to_sym]
              found.nil? ? match : found.to_s
            end

          insts = <<~TEXT
          #{system_insts}
          #{available_tools.map(&:custom_system_message).compact_blank.join("\n")}
          TEXT

          { insts: insts }.tap do |prompt|
            prompt[:tools] = available_tools.map(&:signature) if available_tools
            prompt[:conversation_context] = context[:conversation_context] if context[
              :conversation_context
            ]
          end
        end

        def find_tool(partial)
          parsed_function = Nokogiri::HTML5.fragment(partial)
          function_name = parsed_function.at("tool_name")&.text
          return nil if function_name.nil?

          tool_klass = available_tools.find { |c| c.signature.dig(:name) == function_name }
          return nil if tool_klass.nil?

          arguments =
            tool_klass.signature[:parameters]
              .to_a
              .reduce({}) do |memo, p|
                argument = parsed_function.at(p[:name])&.text
                next(memo) unless argument

                memo[p[:name].to_sym] = argument
                memo
              end

          tool_klass.new(arguments, persona_options: options[tool_klass])
        end
      end
    end
  end
end
