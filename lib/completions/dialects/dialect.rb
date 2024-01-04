# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Dialect
        class << self
          def can_translate?(_model_name)
            raise NotImplemented
          end

          def dialect_for(model_name)
            dialects = [
              DiscourseAi::Completions::Dialects::Claude,
              DiscourseAi::Completions::Dialects::Llama2Classic,
              DiscourseAi::Completions::Dialects::ChatGpt,
              DiscourseAi::Completions::Dialects::OrcaStyle,
              DiscourseAi::Completions::Dialects::Gemini,
              DiscourseAi::Completions::Dialects::Mixtral,
            ]

            dialect = dialects.find { |d| d.can_translate?(model_name) }
            raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL if !dialect
            dialect
          end

          def tokenizer
            raise NotImplemented
          end
        end

        def initialize(generic_prompt, model_name, opts: {})
          @prompt = generic_prompt
          @model_name = model_name
          @opts = opts
        end

        def translate
          raise NotImplemented
        end

        def tools
          tools = +""

          prompt[:tools].each do |function|
            parameters = +""
            if function[:parameters].present?
              function[:parameters].each do |parameter|
                parameters << <<~PARAMETER
                  <parameter>
                  <name>#{parameter[:name]}</name>
                  <type>#{parameter[:type]}</type>
                  <description>#{parameter[:description]}</description>
                  <required>#{parameter[:required]}</required>
                PARAMETER
                if parameter[:enum]
                  parameters << "<options>#{parameter[:enum].join(",")}</options>\n"
                end
                parameters << "</parameter>\n"
              end
            end

            tools << <<~TOOLS
              <tool_description>
              <tool_name>#{function[:name]}</tool_name>
              <description>#{function[:description]}</description>
              <parameters>
              #{parameters}</parameters>
              </tool_description>
            TOOLS
          end

          tools
        end

        def conversation_context
          raise NotImplemented
        end

        def max_prompt_tokens
          raise NotImplemented
        end

        private

        attr_reader :prompt, :model_name, :opts

        def trim_context(conversation_context)
          prompt_limit = max_prompt_tokens
          current_token_count = calculate_token_count_without_context
          message_step_size = (max_prompt_tokens / 25).to_i * -1

          conversation_context.reduce([]) do |memo, context|
            break(memo) if current_token_count >= prompt_limit

            dupped_context = context.dup

            message_tokens = calculate_message_token(dupped_context)

            # Don't trim tool call metadata.
            if context[:type] == "tool_call"
              current_token_count += calculate_message_token(context) + per_message_overhead
              memo << context
              next(memo)
            end

            # Trimming content to make sure we respect token limit.
            while dupped_context[:content].present? &&
                    message_tokens + current_token_count + per_message_overhead > prompt_limit
              dupped_context[:content] = dupped_context[:content][0..message_step_size] || ""
              message_tokens = calculate_message_token(dupped_context)
            end

            next(memo) if dupped_context[:content].blank?

            current_token_count += message_tokens + per_message_overhead

            memo << dupped_context
          end
        end

        def calculate_token_count_without_context
          tokenizer = self.class.tokenizer

          examples_count =
            prompt[:examples].to_a.sum do |pair|
              tokenizer.size(pair.join) + (per_message_overhead * 2)
            end
          input_count = tokenizer.size(prompt[:input].to_s) + per_message_overhead

          examples_count + input_count +
            prompt
              .except(:conversation_context, :tools, :examples, :input)
              .sum { |_, v| tokenizer.size(v) + per_message_overhead }
        end

        def per_message_overhead
          0
        end

        def calculate_message_token(context)
          self.class.tokenizer.size(context[:content].to_s)
        end

        def build_tools_prompt
          return "" if prompt[:tools].blank?

          <<~TEXT
            In this environment you have access to a set of tools you can use to answer the user's question.
            You may call them like this. Only invoke one function at a time and wait for the results before invoking another function:
            <function_calls>
            <invoke>
            <tool_name>$TOOL_NAME</tool_name>
            <parameters>
            <$PARAMETER_NAME>$PARAMETER_VALUE</$PARAMETER_NAME>
            ...
            </parameters>
            </invoke>
            </function_calls>

            Here are the tools available:

            <tools>
            #{tools}</tools>
          TEXT
        end

        def flatten_context(context)
          found_first_multi_turn = false

          context
            .map do |a_context|
              if a_context[:type] == "multi_turn"
                if found_first_multi_turn
                  # Only take tool and tool_call_id from subsequent multi-turn interactions.
                  # Drop assistant responses
                  a_context[:content].last(2)
                else
                  found_first_multi_turn = true
                  a_context[:content]
                end
              else
                a_context
              end
            end
            .flatten
        end
      end
    end
  end
end
