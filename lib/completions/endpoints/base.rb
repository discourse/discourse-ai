# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Base
        CompletionFailed = Class.new(StandardError)
        TIMEOUT = 60

        def self.endpoint_for(model_name)
          # Order is important.
          # Bedrock has priority over Anthropic if creadentials are present.
          [
            DiscourseAi::Completions::Endpoints::AwsBedrock,
            DiscourseAi::Completions::Endpoints::Anthropic,
            DiscourseAi::Completions::Endpoints::OpenAI,
            DiscourseAi::Completions::Endpoints::Huggingface,
          ].detect(-> { raise DiscourseAi::Completions::LLM::UNKNOWN_MODEL }) do |ek|
            ek.can_contact?(model_name)
          end
        end

        def self.can_contact?(_model_name)
          raise NotImplementedError
        end

        def initialize(model_name, tokenizer)
          @model = model_name
          @tokenizer = tokenizer
        end

        def perform_completion!(prompt, user, model_params = {})
          @streaming_mode = block_given?

          Net::HTTP.start(
            model_uri.host,
            model_uri.port,
            use_ssl: true,
            read_timeout: TIMEOUT,
            open_timeout: TIMEOUT,
            write_timeout: TIMEOUT,
          ) do |http|
            response_data = +""
            response_raw = +""
            request_body = prepare_payload(prompt, model_params).to_json

            request = prepare_request(request_body)

            http.request(request) do |response|
              if response.code.to_i != 200
                Rails.logger.error(
                  "#{self.class.name}: status: #{response.code.to_i} - body: #{response.body}",
                )
                raise CompletionFailed
              end

              log =
                AiApiAuditLog.new(
                  provider_id: provider_id,
                  user_id: user&.id,
                  raw_request_payload: request_body,
                  request_tokens: prompt_size(prompt),
                )

              if !@streaming_mode
                response_raw = response.read_body
                response_data = extract_completion_from(response_raw)

                return response_data
              end

              begin
                cancelled = false
                cancel = lambda { cancelled = true }

                leftover = ""

                response.read_body do |chunk|
                  if cancelled
                    http.finish
                    return
                  end

                  decoded_chunk = decode(chunk)
                  response_raw << decoded_chunk

                  partials_from(leftover + decoded_chunk).each do |raw_partial|
                    next if cancelled
                    next if raw_partial.blank?

                    begin
                      partial = extract_completion_from(raw_partial)
                      leftover = ""
                      response_data << partial

                      yield partial, cancel if partial
                    rescue JSON::ParserError
                      leftover = raw_partial
                    end
                  end
                end
              rescue IOError, StandardError
                raise if !cancelled
              end

              return response_data
            ensure
              if log
                log.raw_response_payload = response_raw
                log.response_tokens = tokenizer.size(response_data)
                log.save!

                if Rails.env.development?
                  puts "#{self.class.name}: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
                end
              end
            end
          end
        end

        def default_options
          raise NotImplementedError
        end

        def provider_id
          raise NotImplementedError
        end

        def prompt_size(prompt)
          tokenizer.size(extract_prompt_for_tokenizer(prompt))
        end

        attr_reader :tokenizer

        protected

        attr_reader :model

        def model_uri
          raise NotImplementedError
        end

        def prepare_payload(_prompt, _model_params)
          raise NotImplementedError
        end

        def prepare_request(_payload)
          raise NotImplementedError
        end

        def extract_completion_from(_response_raw)
          raise NotImplementedError
        end

        def decode(chunk)
          chunk
        end

        def partials_from(_decoded_chunk)
          raise NotImplementedError
        end

        def extract_prompt_for_tokenizer(prompt)
          prompt
        end
      end
    end
  end
end
