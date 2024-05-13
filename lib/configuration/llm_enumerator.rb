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
    end
  end
end
