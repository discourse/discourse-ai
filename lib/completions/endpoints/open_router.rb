# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenRouter < OpenAi
        def self.can_contact?(model_provider)
          %w[open_router].include?(model_provider)
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }
          api_key = llm_model.api_key

          headers["Authorization"] = "Bearer #{api_key}"
          headers["X-Title"] = "Discourse AI"
          headers["HTTP-Referer"] = "https://www.discourse.org/ai"

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = super

          if quantizations = llm_model.provider_params["provider_quantizations"].presence
            options = quantizations.split(",").map(&:strip)

            payload[:provider] = { quantizations: options }
          end

          if order = llm_model.provider_params["provider_order"].presence
            options = order.split(",").map(&:strip)
            payload[:provider] ||= {}
            payload[:provider][:order] = options
          end

          payload
        end
      end
    end
  end
end
