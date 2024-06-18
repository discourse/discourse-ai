# frozen_string_literal: true

require "enum_site_setting"

module DiscourseAi
  module Configuration
    class LlmEnumerator < ::EnumSiteSetting
      def self.valid_value?(val)
        true
      end

      def self.values
        begin
          llm_models =
            DiscourseAi::Completions::Llm.models_by_provider.flat_map do |provider, models|
              endpoint = DiscourseAi::Completions::Endpoints::Base.endpoint_for(provider.to_s)

              models.map do |model_name|
                { name: endpoint.display_name(model_name), value: "#{provider}:#{model_name}" }
              end
            end

          LlmModel.all.each do |model|
            llm_models << { name: model.display_name, value: "custom:#{model.id}" }
          end

          llm_models
        end
      end

      def self.available_ai_bots
        %w[
          gpt-3.5-turbo
          gpt-4
          gpt-4-turbo
          gpt-4o
          claude-2
          gemini-1.5-pro
          mixtral-8x7B-Instruct-V0.1
          claude-3-opus
          claude-3-sonnet
          claude-3-haiku
          cohere-command-r-plus
        ]
      end
    end
  end
end
