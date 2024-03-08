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
          messages = prompt.messages
          trimmed_messages = trim_messages(messages)

          # Need to include this differently
          last_message = trimmed_messages.last[:type] == :assistant ? trimmed_messages.pop : nil

          llama2_prompt =
            trimmed_messages.reduce(+"") do |memo, msg|
              if msg[:type] == :tool_call
                memo << "\n### Assistant:\n"
                memo << tool_call_to_xml(msg)
              elsif msg[:type] == :system
                memo << (<<~TEXT).strip
                ### System:
                #{msg[:content]}
                #{build_tools_prompt}
                TEXT
              elsif msg[:type] == :model
                memo << "\n### Assistant:\n#{msg[:content]}"
              elsif msg[:type] == :tool
                memo << "\n### User:\n"
                memo << tool_result_to_xml(msg)
              else
                memo << "\n### User:\n#{msg[:content]}"
              end

              memo
            end

          llama2_prompt << "\n### Assistant:\n"
          llama2_prompt << "#{last_message[:content]}:" if last_message

          llama2_prompt
        end

        def max_prompt_tokens
          SiteSetting.ai_hugging_face_token_limit
        end
      end
    end
  end
end
