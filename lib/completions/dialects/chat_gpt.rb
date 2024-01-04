# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class ChatGpt < Dialect
        class << self
          def can_translate?(model_name)
            %w[
              gpt-3.5-turbo
              gpt-4
              gpt-3.5-turbo-16k
              gpt-4-32k
              gpt-4-1106-preview
              gpt-4-turbo
            ].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::OpenAiTokenizer
          end
        end

        def translate
          open_ai_prompt = [
            { role: "system", content: [prompt[:insts], prompt[:post_insts].to_s].join("\n") },
          ]

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              open_ai_prompt << { role: "user", content: example_pair.first }
              open_ai_prompt << { role: "assistant", content: example_pair.second }
            end
          end

          open_ai_prompt.concat(conversation_context) if prompt[:conversation_context]

          open_ai_prompt << { role: "user", content: prompt[:input] } if prompt[:input]

          open_ai_prompt
        end

        def tools
          return if prompt[:tools].blank?

          prompt[:tools].map do |t|
            tool = t.dup

            tool[:parameters] = t[:parameters]
              .to_a
              .reduce({ type: "object", properties: {}, required: [] }) do |memo, p|
                name = p[:name]
                memo[:required] << name if p[:required]

                memo[:properties][name] = p.except(:name, :required, :item_type)

                memo[:properties][name][:items] = { type: p[:item_type] } if p[:item_type]
                memo
              end

            { type: "function", function: tool }
          end
        end

        def conversation_context
          return [] if prompt[:conversation_context].blank?

          flattened_context = flatten_context(prompt[:conversation_context])
          trimmed_context = trim_context(flattened_context)

          trimmed_context.reverse.map do |context|
            if context[:type] == "tool_call"
              function = JSON.parse(context[:content], symbolize_names: true)
              function[:arguments] = function[:arguments].to_json

              {
                role: "assistant",
                tool_calls: [{ type: "function", function: function, id: context[:name] }],
              }
            else
              translated = context.slice(:content)
              translated[:role] = context[:type]

              if context[:name]
                if translated[:role] == "tool"
                  translated[:tool_call_id] = context[:name]
                else
                  translated[:name] = context[:name]
                end
              end

              translated
            end
          end
        end

        def max_prompt_tokens
          # provide a buffer of 120 tokens - our function counting is not
          # 100% accurate and getting numbers to align exactly is very hard
          buffer = (opts[:max_tokens] || 2500) + 50

          if tools.present?
            # note this is about 100 tokens over, OpenAI have a more optimal representation
            @function_size ||= self.class.tokenizer.size(tools.to_json.to_s)
            buffer += @function_size
          end

          model_max_tokens - buffer
        end

        private

        def per_message_overhead
          # open ai defines about 4 tokens per message of overhead
          4
        end

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s + context[:name].to_s)
        end

        def model_max_tokens
          case model_name
          when "gpt-3.5-turbo-16k"
            16_384
          when "gpt-4"
            8192
          when "gpt-4-32k"
            32_768
          else
            8192
          end
        end
      end
    end
  end
end
