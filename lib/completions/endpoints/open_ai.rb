# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        def self.can_contact?(model_name)
          %w[gpt-3.5-turbo gpt-4].include?(model_name)
        end

        def default_options
          { model: model }
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        def provider_id
          AiApiAuditLog::Provider::OpenAI
        end

        private

        def model_uri
          url =
            if model.include?("gpt-4")
              if model.include?("32k")
                SiteSetting.ai_openai_gpt4_32k_url
              else
                SiteSetting.ai_openai_gpt4_url
              end
            else
              if model.include?("16k")
                SiteSetting.ai_openai_gpt35_16k_url
              else
                SiteSetting.ai_openai_gpt35_url
              end
            end

          URI(url)
        end

        def prepare_payload(prompt, model_params)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap { |payload| payload[:stream] = true if @streaming_mode }
        end

        def prepare_request(payload)
          headers =
            { "Content-Type" => "application/json" }.tap do |h|
              if model_uri.host.include?("azure")
                h["api-key"] = SiteSetting.ai_openai_api_key
              else
                h["Authorization"] = "Bearer #{SiteSetting.ai_openai_api_key}"
              end

              if SiteSetting.ai_openai_organization.present?
                h["OpenAI-Organization"] = SiteSetting.ai_openai_organization
              end
            end

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)

          (
            if @streaming_mode
              parsed.dig(:choices, 0, :delta, :content)
            else
              parsed.dig(:choices, 0, :message, :content)
            end
          ).to_s
        end

        def partials_from(decoded_chunk)
          decoded_chunk
            .split("\n")
            .map do |line|
              data = line.split("data: ", 2)[1]
              data == "[DONE]" ? nil : data
            end
            .compact
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt.map { |message| message[:content] || message["content"] || "" }.join("\n")
        end
      end
    end
  end
end
