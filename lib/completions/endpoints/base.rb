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

                if has_tool?("", response_data)
                  function_buffer = build_buffer # Nokogiri document
                  function_buffer = add_to_buffer(function_buffer, "", response_data)

                  response_data = +function_buffer.at("function_calls").to_s
                  response_data << "\n"
                end

                return response_data
              end

              begin
                cancelled = false
                cancel = lambda { cancelled = true }

                leftover = ""
                function_buffer = build_buffer # Nokogiri document

                response.read_body do |chunk|
                  if cancelled
                    http.finish
                    return
                  end

                  decoded_chunk = decode(chunk)
                  response_raw << decoded_chunk

                  # Buffering for extremely slow streaming.
                  if (leftover + decoded_chunk).length < "data: [DONE]".length
                    leftover += decoded_chunk
                    next
                  end

                  partials_from(leftover + decoded_chunk).each do |raw_partial|
                    next if cancelled
                    next if raw_partial.blank?

                    begin
                      partial = extract_completion_from(raw_partial)
                      next if partial.nil?
                      leftover = ""

                      if has_tool?(response_data, partial)
                        function_buffer = add_to_buffer(function_buffer, response_data, partial)

                        if buffering_finished?(dialect.tools, function_buffer)
                          invocation = +function_buffer.at("function_calls").to_s
                          invocation << "\n"

                          partials_raw << partial.to_s
                          response_data << invocation

                          yield invocation, cancel
                        end
                      else
                        partials_raw << partial
                        response_data << partial

                        yield partial, cancel if partial
                      end
                    rescue JSON::ParserError
                      leftover += decoded_chunk
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
          <parameters></parameters>
          </invoke>
          </function_calls>
          TEXT
        end

        def has_tool?(response, partial)
          (response + partial).include?("<function_calls>")
        end

        def add_to_buffer(function_buffer, response_data, partial)
          new_buffer = Nokogiri::HTML5.fragment(response_data + partial)
          if tool_name = new_buffer.at("tool_name").text
            if new_buffer.at("tool_id").nil?
              tool_id_node =
                Nokogiri::HTML5::DocumentFragment.parse("\n<tool_id>#{tool_name}</tool_id>")

              new_buffer.at("invoke").children[1].add_next_sibling(tool_id_node)
            end
          end

          new_buffer
        end

        def buffering_finished?(_available_functions, buffer)
          buffer.to_s.include?("</function_calls>")
        end
      end
    end
  end
end
