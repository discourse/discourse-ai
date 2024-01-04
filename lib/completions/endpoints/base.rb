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
            DiscourseAi::Completions::Endpoints::OpenAi,
            DiscourseAi::Completions::Endpoints::HuggingFace,
            DiscourseAi::Completions::Endpoints::Gemini,
            DiscourseAi::Completions::Endpoints::Vllm,
          ].detect(-> { raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL }) do |ek|
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

        def perform_completion!(dialect, user, model_params = {})
          model_params = normalize_model_params(model_params)

          @streaming_mode = block_given?

          prompt = dialect.translate

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

            # Needed to response token calculations. Cannot rely on response_data due to function buffering.
            partials_raw = +""
            request_body = prepare_payload(prompt, model_params, dialect).to_json

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
                partials_raw = response_data.to_s

                if has_tool?(response_data)
                  function_buffer = build_buffer # Nokogiri document
                  function_buffer = add_to_buffer(function_buffer, "", response_data)

                  response_data = +function_buffer.at("function_calls").to_s
                  response_data << "\n"
                end

                return response_data
              end

              has_tool = false

              begin
                cancelled = false
                cancel = lambda { cancelled = true }

                leftover = ""
                function_buffer = build_buffer # Nokogiri document
                prev_processed_partials = 0

                response.read_body do |chunk|
                  if cancelled
                    http.finish
                    break
                  end

                  decoded_chunk = decode(chunk)
                  response_raw << decoded_chunk

                  redo_chunk = leftover + decoded_chunk

                  raw_partials = partials_from(redo_chunk)

                  raw_partials =
                    raw_partials[prev_processed_partials..-1] if prev_processed_partials > 0

                  if raw_partials.blank? || (raw_partials.size == 1 && raw_partials.first.blank?)
                    leftover = redo_chunk
                    next
                  end

                  json_error = false

                  raw_partials.each do |raw_partial|
                    json_error = false
                    prev_processed_partials += 1

                    next if cancelled
                    next if raw_partial.blank?

                    begin
                      partial = extract_completion_from(raw_partial)
                      next if response_data.empty? && partial.blank?
                      next if partial.nil?
                      partials_raw << partial.to_s

                      # Stop streaming the response as soon as you find a tool.
                      # We'll buffer and yield it later.
                      has_tool = true if has_tool?(partials_raw)

                      if has_tool
                        function_buffer = add_to_buffer(function_buffer, partials_raw, partial)
                      else
                        response_data << partial

                        yield partial, cancel if partial
                      end
                    rescue JSON::ParserError
                      leftover = redo_chunk
                      json_error = true
                    end
                  end

                  if json_error
                    prev_processed_partials -= 1
                  else
                    leftover = ""
                  end
                  prev_processed_partials = 0 if leftover.blank?
                end
              rescue IOError, StandardError
                raise if !cancelled
              end

              # Once we have the full response, try to return the tool as a XML doc.
              if has_tool
                if function_buffer.at("tool_name").text.present?
                  invocation = +function_buffer.at("function_calls").to_s
                  invocation << "\n"

                  response_data << invocation
                  yield invocation, cancel
                end
              end

              return response_data
            ensure
              if log
                log.raw_response_payload = response_raw
                log.response_tokens = tokenizer.size(partials_raw)
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

        # should normalize temperature, max_tokens, stop_words to endpoint specific values
        def normalize_model_params(model_params)
          raise NotImplementedError
        end

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

        def build_buffer
          Nokogiri::HTML5.fragment(<<~TEXT)
          <function_calls>
          <invoke>
          <tool_name></tool_name>
          <tool_id></tool_id>
          <parameters>
          </parameters>
          </invoke>
          </function_calls>
          TEXT
        end

        def has_tool?(response)
          response.include?("<function")
        end

        def add_to_buffer(function_buffer, response_data, partial)
          raw_data = (response_data + partial)

          # recover stop word potentially
          raw_data =
            raw_data.split("</invoke>").first + "</invoke>\n</function_calls>" if raw_data.split(
            "</invoke>",
          ).length > 1

          return function_buffer unless raw_data.include?("</invoke>")

          read_function = Nokogiri::HTML5.fragment(raw_data)

          if tool_name = read_function.at("tool_name")&.text
            function_buffer.at("tool_name").inner_html = tool_name
            function_buffer.at("tool_id").inner_html = tool_name
          end

          _read_parameters =
            read_function
              .at("parameters")
              &.elements
              .to_a
              .each do |elem|
                if paramenter = function_buffer.at(elem.name)&.text
                  function_buffer.at(elem.name).inner_html = paramenter
                else
                  param_node = read_function.at(elem.name)
                  function_buffer.at("parameters").add_child(param_node)
                  function_buffer.at("parameters").add_child("\n")
                end
              end

          function_buffer
        end
      end
    end
  end
end
