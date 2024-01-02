# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Llama2Classic < Dialect
        class << self
          def can_translate?(model_name)
            %w[Llama2-*-chat-hf Llama2-chat-hf].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::Llama2Tokenizer
          end
        end

        def translate
          llama2_prompt = +<<~TEXT
          [INST]
          <<SYS>>
          #{prompt[:insts]}
          #{build_tools_prompt}#{prompt[:post_insts]}
          <</SYS>>
          [/INST]
          TEXT

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              llama2_prompt << "[INST]#{example_pair.first}[/INST]\n"
              llama2_prompt << "#{example_pair.second}\n"
            end
          end

          llama2_prompt << conversation_context if prompt[:conversation_context].present?

          llama2_prompt << "[INST]#{prompt[:input]}[/INST]\n"
        end

        def conversation_context
          return "" if prompt[:conversation_context].blank?

          trimmed_context = trim_context(prompt[:conversation_context])

          trimmed_context
            .reverse
            .reduce(+"") do |memo, context|
              next(memo) if context[:type] == "tool_call"
              if context[:type] == "tool"
                memo << <<~TEXT
                [INST]
                <function_results>
                <result>
                <tool_name>#{context[:name]}</tool_name>
                <json>
                #{context[:content]}
                </json>
                </result>
                </function_results>
                [/INST]
                TEXT
              elsif context[:type] == "assistant"
                memo << "[INST]" << context[:content] << "[/INST]\n"
              else
                memo << context[:content] << "\n"
              end

              memo
            end
        end

        def max_prompt_tokens
          SiteSetting.ai_hugging_face_token_limit
        end
      end
    end
  end
end
