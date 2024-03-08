# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Gemini < Dialect
        class << self
          def can_translate?(model_name)
            %w[gemini-pro].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::OpenAiTokenizer ## TODO Replace with GeminiTokenizer
          end
        end

        def translate
          # Gemini complains if we don't alternate model/user roles.
          noop_model_response = { role: "model", parts: { text: "Ok." } }

          messages = prompt.messages

          # Gemini doesn't use an assistant msg to improve long-context responses.
          messages.pop if messages.last[:type] == :model

          memo = []

          trim_messages(messages).each do |msg|
            if msg[:type] == :system
              memo << { role: "user", parts: { text: msg[:content] } }
              memo << noop_model_response.dup
            elsif msg[:type] == :model
              memo << { role: "model", parts: { text: msg[:content] } }
            elsif msg[:type] == :tool_call
              call_details = JSON.parse(msg[:content], symbolize_names: true)

              memo << {
                role: "model",
                parts: {
                  functionCall: {
                    name: msg[:name] || call_details[:name],
                    args: call_details[:arguments],
                  },
                },
              }
            elsif msg[:type] == :tool
              memo << {
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
            else
              # Gemini quirk. Doesn't accept tool -> user or user -> user msgs.
              previous_msg_role = memo.last&.dig(:role)
              if previous_msg_role == "user" || previous_msg_role == "function"
                memo << noop_model_response.dup
              end

              memo << { role: "user", parts: { text: msg[:content] } }
            end
          end

          memo
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
          16_384 # 50% of model tokens
        end

        protected

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end
      end
    end
  end
end
