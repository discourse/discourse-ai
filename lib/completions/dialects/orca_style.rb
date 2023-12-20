# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OrcaStyle < Dialect
        class << self
          def can_translate?(model_name)
            %w[StableBeluga2 Upstage-Llama-2-*-instruct-v2].include?(model_name)
          end

          def tokenizer
            DiscourseAi::Tokenizer::Llama2Tokenizer
          end
        end

        def translate
          orca_style_prompt = +<<~TEXT
          ### System:
          #{prompt[:insts]}
          #{build_tools_prompt}#{prompt[:post_insts]}
          TEXT

          if prompt[:examples]
            prompt[:examples].each do |example_pair|
              orca_style_prompt << "### User:\n#{example_pair.first}\n"
              orca_style_prompt << "### Assistant:\n#{example_pair.second}\n"
            end
          end

          orca_style_prompt << "### User:\n#{prompt[:input]}\n"

          orca_style_prompt << "### Assistant:\n"
        end

        def conversation_context
          return "" if prompt[:conversation_context].blank?

          trimmed_context = trim_context(prompt[:conversation_context])

          trimmed_context
            .reverse
            .reduce(+"") do |memo, context|
              memo << (context[:type] == "user" ? "### User:" : "### Assistant:")

              if context[:type] == "tool"
                memo << <<~TEXT

                <function_results>
                <result>
                <tool_name>#{context[:name]}</tool_name>
                <json>
                #{context[:content]}
                </json>
                </result>
                </function_results>
                TEXT
              else
                memo << " " << context[:content] << "\n"
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
