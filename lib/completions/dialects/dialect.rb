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
              DiscourseAi::Completions::Dialects::ClaudeMessages,
            ]

            if Rails.env.test? || Rails.env.development?
              dialects << DiscourseAi::Completions::Dialects::Fake
            end

            dialect = dialects.find { |d| d.can_translate?(model_name) }
            raise DiscourseAi::Completions::Llm::UNKNOWN_MODEL if !dialect
            dialect
          end

          def tokenizer
            raise NotImplemented
          end

          def tool_preamble
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

              if a parameter type is an array, return a JSON array of values. For example:
              [1,"two",3.0]

              Here are the tools available:
            TEXT
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

        def tool_result_to_xml(message)
          (<<~TEXT).strip
            <function_results>
            <result>
            <tool_name>#{message[:id]}</tool_name>
            <json>
            #{message[:content]}
            </json>
            </result>
            </function_results>
          TEXT
        end

        def tool_call_to_xml(message)
          parsed = JSON.parse(message[:content], symbolize_names: true)
          parameters = +""

          if parsed[:arguments]
            parameters << "<parameters>\n"
            parsed[:arguments].each { |k, v| parameters << "<#{k}>#{v}</#{k}>\n" }
            parameters << "</parameters>\n"
          end

          (<<~TEXT).strip
            <function_calls>
            <invoke>
            <tool_name>#{parsed[:name]}</tool_name>
            #{parameters}</invoke>
            </function_calls>
          TEXT
        end

        def tools
          tools = +""

          prompt.tools.each do |function|
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

        attr_reader :prompt

        private

        attr_reader :model_name, :opts

        def trim_messages(messages)
          prompt_limit = max_prompt_tokens
          current_token_count = 0
          message_step_size = (max_prompt_tokens / 25).to_i * -1

          trimmed_messages = []

          range = (0..-1)
          if messages.dig(0, :type) == :system
            system_message = messages[0]
            trimmed_messages << system_message
            current_token_count += calculate_message_token(system_message)
            range = (1..-1)
          end

          reversed_trimmed_msgs = []

          messages[range].reverse.each do |msg|
            break if current_token_count >= prompt_limit

            message_tokens = calculate_message_token(msg)

            dupped_msg = msg.dup

            # Don't trim tool call metadata.
            if msg[:type] == :tool_call
              break if current_token_count + message_tokens + per_message_overhead > prompt_limit

              current_token_count += message_tokens + per_message_overhead
              reversed_trimmed_msgs << dupped_msg
              next
            end

            # Trimming content to make sure we respect token limit.
            while dupped_msg[:content].present? &&
                    message_tokens + current_token_count + per_message_overhead > prompt_limit
              dupped_msg[:content] = dupped_msg[:content][0..message_step_size] || ""
              message_tokens = calculate_message_token(dupped_msg)
            end

            next if dupped_msg[:content].blank?

            current_token_count += message_tokens + per_message_overhead

            reversed_trimmed_msgs << dupped_msg
          end

          reversed_trimmed_msgs.pop if reversed_trimmed_msgs.last&.dig(:type) == :tool

          trimmed_messages.concat(reversed_trimmed_msgs.reverse)
        end

        def per_message_overhead
          0
        end

        def calculate_message_token(msg)
          self.class.tokenizer.size(msg[:content].to_s)
        end

        def build_tools_prompt
          return "" if prompt.tools.blank?

          (<<~TEXT).strip
            #{self.class.tool_preamble}
            <tools>
            #{tools}</tools>
          TEXT
        end
      end
    end
  end
end
