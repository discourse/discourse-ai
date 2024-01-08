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

          gemini_prompt = [
            {
              role: "user",
              parts: {
                text: [prompt[:insts], prompt[:post_insts].to_s].join("\n"),
              },
            },
            noop_model_response,
          ]

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              gemini_prompt << { role: "user", parts: { text: example_pair.first } }
              gemini_prompt << { role: "model", parts: { text: example_pair.second } }
            end
          end

          gemini_prompt.concat(conversation_context) if prompt[:conversation_context]

          if prompt[:input]
            gemini_prompt << noop_model_response.dup if gemini_prompt.last[:role] == "user"

            gemini_prompt << { role: "user", parts: { text: prompt[:input] } }
          end

          gemini_prompt
        end

        def tools
          return if prompt[:tools].blank?

          translated_tools =
            prompt[:tools].map do |t|
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

        def conversation_context
          return [] if prompt[:conversation_context].blank?

          flattened_context = flatten_context(prompt[:conversation_context])
          trimmed_context = trim_context(flattened_context)

          trimmed_context.reverse.map do |context|
            if context[:type] == "tool_call"
              function = JSON.parse(context[:content], symbolize_names: true)

              {
                role: "model",
                parts: {
                  functionCall: {
                    name: function[:name],
                    args: function[:arguments],
                  },
                },
              }
            elsif context[:type] == "tool"
              {
                role: "function",
                parts: {
                  functionResponse: {
                    name: context[:name],
                    response: {
                      content: context[:content],
                    },
                  },
                },
              }
            else
              {
                role: context[:type] == "assistant" ? "model" : "user",
                parts: {
                  text: context[:content],
                },
              }
            end
          end
        end

        def max_prompt_tokens
          16_384 # 50% of model tokens
        end

        protected

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end

        private

        def flatten_context(context)
          flattened = []
          context.each do |c|
            if c[:type] == "multi_turn"
              # gemini quirk
              if c[:content].first[:type] == "tool"
                flattend << { type: "assistant", content: "ok." }
              end

              flattened.concat(c[:content])
            else
              flattened << c
            end
          end
          flattened
        end
      end
    end
  end
end
