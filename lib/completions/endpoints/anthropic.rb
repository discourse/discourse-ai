# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        class << self
          def can_contact?(endpoint_name, model_name)
            endpoint_name == "anthropic" &&
              %w[claude-instant-1 claude-2 claude-3-haiku claude-3-opus claude-3-sonnet].include?(
                model_name,
              )
          end

          def dependant_setting_names
            %w[ai_anthropic_api_key]
          end

          def correctly_configured?(_model_name)
            SiteSetting.ai_anthropic_api_key.present?
          end

          def endpoint_name(model_name)
            "Anthropic - #{model_name}"
          end
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        def default_options(dialect)
          # skipping 2.0 support for now, since other models are better
          mapped_model =
            case model
            when "claude-2"
              "claude-2.1"
            when "claude-instant-1"
              "claude-instant-1.2"
            when "claude-3-haiku"
              "claude-3-haiku-20240307"
            when "claude-3-sonnet"
              "claude-3-sonnet-20240229"
            when "claude-3-opus"
              "claude-3-opus-20240229"
            else
              raise "Unsupported model: #{model}"
            end

          options = { model: mapped_model, max_tokens: 3_000 }

          options[:stop_sequences] = ["</function_calls>"] if dialect.prompt.has_tools?
          options
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        # this is an approximation, we will update it later if request goes through
        def prompt_size(prompt)
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def model_uri
          @uri ||= URI("https://api.anthropic.com/v1/messages")
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options(dialect).merge(model_params).merge(messages: prompt.messages)

          payload[:system] = prompt.system_prompt if prompt.system_prompt.present?
          payload[:stream] = true if @streaming_mode

          payload
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => SiteSetting.ai_anthropic_api_key,
            "content-type" => "application/json",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def final_log_update(log)
          log.request_tokens = @input_tokens if @input_tokens
          log.response_tokens = @output_tokens if @output_tokens
        end

        def extract_completion_from(response_raw)
          result = ""
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            if parsed[:type] == "content_block_start" || parsed[:type] == "content_block_delta"
              result = parsed.dig(:delta, :text).to_s
            elsif parsed[:type] == "message_start"
              @input_tokens = parsed.dig(:message, :usage, :input_tokens)
            elsif parsed[:type] == "message_delta"
              @output_tokens = parsed.dig(:delta, :usage, :output_tokens)
            end
          else
            result = parsed.dig(:content, 0, :text).to_s
            @input_tokens = parsed.dig(:usage, :input_tokens)
            @output_tokens = parsed.dig(:usage, :output_tokens)
          end

          result
        end

        def partials_from(decoded_chunk)
          decoded_chunk.split("\n").map { |line| line.split("data: ", 2)[1] }.compact
        end
      end
    end
  end
end
