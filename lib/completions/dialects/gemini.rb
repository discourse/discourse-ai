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
          gemini_prompt = [
            {
              role: "user",
              parts: {
                text: [prompt[:insts], prompt[:post_insts].to_s].join("\n"),
              },
            },
            { role: "model", parts: { text: "Ok." } },
          ]

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              gemini_prompt << { role: "user", parts: { text: example_pair.first } }
              gemini_prompt << { role: "model", parts: { text: example_pair.second } }
            end
          end

          gemini_prompt.concat(conversation_context) if prompt[:conversation_context]

          gemini_prompt << { role: "user", parts: { text: prompt[:input] } }
        end

        def tools
          return if prompt[:tools].blank?

          translated_tools =
            prompt[:tools].map do |t|
              required_fields = []
              tool = t.dup

              tool[:parameters] = t[:parameters].map do |p|
                required_fields << p[:name] if p[:required]

                p.except(:required)
              end

              tool.merge(required: required_fields)
            end

          [{ function_declarations: translated_tools }]
        end

        def conversation_context
          return [] if prompt[:conversation_context].blank?

          trimmed_context = trim_context(prompt[:conversation_context])

          trimmed_context.reverse.map do |context|
            translated = {}
            translated[:role] = (context[:type] == "user" ? "user" : "model")

            part = {}

            if context[:type] == "tool"
              part["functionResponse"] = { name: context[:name], content: context[:content] }
            else
              part[:text] = context[:content]
            end

            translated[:parts] = [part]

            translated
          end
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
