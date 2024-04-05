# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Base
        CompletionFailed = Class.new(StandardError)
        TIMEOUT = 60

        class << self
          def endpoint_for(provider_name, model_name)
            endpoints = [
              DiscourseAi::Completions::Endpoints::AwsBedrock,
              DiscourseAi::Completions::Endpoints::OpenAi,
              DiscourseAi::Completions::Endpoints::HuggingFace,
              DiscourseAi::Completions::Endpoints::Gemini,
              DiscourseAi::Completions::Endpoints::Vllm,
              DiscourseAi::Completions::Endpoints::Anthropic,
              DiscourseAi::Completions::Endpoints::Cohere,
            ]

            if Rails.env.test? || Rails.env.development?
              endpoints << DiscourseAi::Completions::Endpoints::Fake
            end

            endpoints.detect(-> { raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL }) do |ek|
              ek.can_contact?(provider_name, model_name)
            end
          end

          def configuration_hint
            settings = dependant_setting_names
            I18n.t(
              "discourse_ai.llm.endpoints.configuration_hint",
              settings: settings.join(", "),
              count: settings.length,
            )
          end

          def display_name(model_name)
            to_display = endpoint_name(model_name)

            return to_display if correctly_configured?(model_name)

            I18n.t("discourse_ai.llm.endpoints.not_configured", display_name: to_display)
          end

          def dependant_setting_names
            raise NotImplementedError
          end

          def endpoint_name(_model_name)
            raise NotImplementedError
          end

          def can_contact?(_endpoint_name, _model_name)
            raise NotImplementedError
          end
        end

        def initialize(model_name, tokenizer)
          @model = model_name
          @tokenizer = tokenizer
        end

        def perform_completion!(dialect, user, model_params = {})
          allow_tools = dialect.prompt.has_tools?
          model_params = normalize_model_params(model_params)

          @streaming_mode = block_given?

          prompt = dialect.translate

          FinalDestination::HTTP.start(
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
                  topic_id: dialect.prompt.topic_id,
                  post_id: dialect.prompt.post_id,
                )

              if !@streaming_mode
                response_raw = response.read_body
                response_data = extract_completion_from(response_raw)
                partials_raw = response_data.to_s

                if allow_tools && has_tool?(response_data)
                  function_buffer = build_buffer # Nokogiri document
                  function_buffer = add_to_function_buffer(function_buffer, payload: response_data)

                  normalize_function_ids!(function_buffer)

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
                  if decoded_chunk.nil?
                    raise CompletionFailed, "#{self.class.name}: Failed to decode LLM completion"
                  end
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
                  buffered_partials = []

                  raw_partials.each do |raw_partial|
                    json_error = false
                    prev_processed_partials += 1

                    next if cancelled
                    next if raw_partial.blank?

                    begin
                      partial = extract_completion_from(raw_partial)
                      next if partial.nil?
                      # empty vs blank... we still accept " "
                      next if response_data.empty? && partial.empty?
                      partials_raw << partial.to_s

                      # Stop streaming the response as soon as you find a tool.
                      # We'll buffer and yield it later.
                      has_tool = true if allow_tools && has_tool?(partials_raw)

                      if has_tool
                        if buffered_partials.present?
                          joined = buffered_partials.join
                          joined = joined.gsub(/<.+/, "")
                          yield joined, cancel if joined.present?
                          buffered_partials = []
                        end
                        function_buffer = add_to_function_buffer(function_buffer, partial: partial)
                      else
                        if maybe_has_tool?(partials_raw)
                          buffered_partials << partial
                        else
                          if buffered_partials.present?
                            buffered_partials.each do |buffered_partial|
                              response_data << buffered_partial
                              yield buffered_partial, cancel
                            end
                            buffered_partials = []
                          end
                          response_data << partial
                          yield partial, cancel if partial
                        end
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
                function_buffer = add_to_function_buffer(function_buffer, payload: partials_raw)

                if function_buffer.at("tool_name").text.present?
                  normalize_function_ids!(function_buffer)

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
                final_log_update(log)
                log.save!

                if Rails.env.development?
                  puts "#{self.class.name}: request_tokens #{log.request_tokens} response_tokens #{log.response_tokens}"
                end
              end
            end
          end
        end

        def normalize_function_ids!(function_buffer)
          function_buffer
            .css("invoke")
            .each_with_index do |invoke, index|
              if invoke.at("tool_id")
                invoke.at("tool_id").content = "tool_#{index}" if invoke
                  .at("tool_id")
                  .content
                  .blank?
              else
                invoke.add_child("<tool_id>tool_#{index}</tool_id>\n") if !invoke.at("tool_id")
              end
            end
        end

        def final_log_update(log)
          # for people that need to override
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

        attr_reader :tokenizer, :model

        protected

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
          #{noop_function_call_text}
          </function_calls>
          TEXT
        end

        def noop_function_call_text
          (<<~TEXT).strip
            <invoke>
            <tool_name></tool_name>
            <parameters>
            </parameters>
            <tool_id></tool_id>
            </invoke>
          TEXT
        end

        def has_tool?(response)
          response.include?("<function_calls>")
        end

        def maybe_has_tool?(response)
          # 16 is the length of function calls
          substring = response[-16..-1] || response
          split = substring.split("<")

          if split.length > 1
            match = "<" + split.last
            "<function_calls>".start_with?(match)
          else
            false
          end
        end

        def add_to_function_buffer(function_buffer, partial: nil, payload: nil)
          if payload&.include?("</invoke>")
            matches = payload.match(%r{<function_calls>.*</invoke>}m)
            function_buffer =
              Nokogiri::HTML5.fragment(matches[0] + "\n</function_calls>") if matches
          end

          function_buffer
        end
      end
    end
  end
end
