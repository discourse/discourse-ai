# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Gemini < Dialect
        class << self
          def can_translate?(model_name)
            %w[gemini-pro gemini-1.5-pro].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::OpenAiTokenizer ## TODO Replace with GeminiTokenizer
          end
        end

        def native_tool_support?
          true
        end

        def translate
          # Gemini complains if we don't alternate model/user roles.
          noop_model_response = { role: "model", parts: { text: "Ok." } }
          messages = super

          interleving_messages = []
          previous_message = nil

          messages.each do |message|
            if previous_message
              if (previous_message[:role] == "user" || previous_message[:role] == "function") &&
                   message[:role] == "user"
                interleving_messages << noop_model_response.dup
              end
            end
            interleving_messages << message
            previous_message = message
          end

          interleving_messages
        end

        def tools
          return if prompt.tools.blank?

          translated_tools =
            prompt.tools.map do |t|
              tool = t.slice(:name, :description)

              if t[:parameters]
                tool[:parameters] = t[:parameters].reduce(
                  { type: "object", required: [], properties: {} },
                ) do |memo, p|
                  name = p[:name]
                  memo[:required] << name if p[:required]

                  memo[:properties][name] = p.except(:name, :required, :item_type)

                  memo[:properties][name][:items] = { type: p[:item_type] } if p[:item_type]
                  memo
                end
              end

              tool
            end

          [{ function_declarations: translated_tools }]
        end

        def max_prompt_tokens
          return opts[:max_prompt_tokens] if opts.dig(:max_prompt_tokens).present?

          if model_name == "gemini-1.5-pro"
            # technically we support 1 million tokens, but we're being conservative
            800_000
          else
            16_384 # 50% of model tokens
          end
        end

        protected

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end

        def system_msg(msg)
          { role: "user", parts: { text: msg[:content] } }
        end

        def model_msg(msg)
          { role: "model", parts: { text: msg[:content] } }
        end

        def user_msg(msg)
          { role: "user", parts: { text: msg[:content] } }
        end

        def tool_call_msg(msg)
          call_details = JSON.parse(msg[:content], symbolize_names: true)

          {
            role: "model",
            parts: {
              functionCall: {
                name: msg[:name] || call_details[:name],
                args: call_details[:arguments],
              },
            },
          }
        end

        def tool_msg(msg)
          {
            role: "function",
            parts: {
              functionResponse: {
                name: msg[:name] || msg[:id],
                response: {
                  content: msg[:content],
                },
              },
            },
          }
        end
      end
    end
  end
end
