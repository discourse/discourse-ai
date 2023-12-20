# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        def self.can_contact?(model_name)
          %w[
            gpt-3.5-turbo
            gpt-4
            gpt-3.5-turbo-16k
            gpt-4-32k
            gpt-4-1106-preview
            gpt-4-turbo
          ].include?(model_name)
        end

        def default_options
          { model: model == "gpt-4-turbo" ? "gpt-4-1106-preview" : model }
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
                if model.include?("1106") || model.include?("turbo")
                  SiteSetting.ai_openai_gpt4_turbo_url
                else
                  SiteSetting.ai_openai_gpt4_url
                end
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

        def prepare_payload(prompt, model_params, dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap do |payload|
              payload[:stream] = true if @streaming_mode
              payload[:tools] = dialect.tools if dialect.tools.present?
            end
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
          parsed = JSON.parse(response_raw, symbolize_names: true).dig(:choices, 0)

          # half a line sent here
          return if !parsed

          response_h = @streaming_mode ? parsed.dig(:delta) : parsed.dig(:message)

          has_function_call = response_h.dig(:tool_calls).present?
          has_function_call ? response_h.dig(:tool_calls, 0, :function) : response_h.dig(:content)
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

        def has_tool?(_response_data, partial)
          partial.is_a?(Hash) && partial.has_key?(:name) # Has function name
        end

        def add_to_buffer(function_buffer, _response_data, partial)
          function_buffer.at("tool_name").content = partial[:name] if partial[:name].present?
          function_buffer.at("tool_id").content = partial[:id] if partial[:id].present?

          if partial[:arguments]
            argument_fragments =
              partial[:arguments].reduce(+"") do |memo, (arg_name, value)|
                memo << "\n<#{arg_name}>#{value}</#{arg_name}>"
              end
            argument_fragments << "\n"

            function_buffer.at("parameters").children =
              Nokogiri::HTML5::DocumentFragment.parse(argument_fragments)
          end

          function_buffer
        end

        def buffering_finished?(available_functions, buffer)
          tool_name = buffer.at("tool_name")&.text
          return false if tool_name.blank?

          signature = available_functions.find { |f| f.dig(:tool, :name) == tool_name }[:tool]

          signature[:parameters].reduce(true) do |memo, param|
            param_present = buffer.at(param[:name]).present?
            next(memo) if param_present && !param[:required]

            memo && param_present
          end
        end
      end
    end
  end
end
