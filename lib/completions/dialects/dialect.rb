# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Dialect
        class << self
          def can_translate?(_model_name)
            raise NotImplemented
          end

          def all_dialects
            [
              DiscourseAi::Completions::Dialects::ChatGpt,
              DiscourseAi::Completions::Dialects::Gemini,
              DiscourseAi::Completions::Dialects::Mistral,
              DiscourseAi::Completions::Dialects::Claude,
              DiscourseAi::Completions::Dialects::Command,
              DiscourseAi::Completions::Dialects::OpenAiCompatible,
            ]
          end

          def available_tokenizers
            all_dialects.map(&:tokenizer)
          end

          def dialect_for(model_name)
            dialects = []

            if Rails.env.test? || Rails.env.development?
              dialects = [DiscourseAi::Completions::Dialects::Fake]
            end

            dialects = dialects.concat(all_dialects)

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

        VALID_ID_REGEX = /\A[a-zA-Z0-9_]+\z/

        def can_end_with_assistant_msg?
          false
        end

        def native_tool_support?
          false
        end

        def tools
          @tools ||= tools_dialect.translated_tools
        end

        def translate
          messages = prompt.messages

          # Some models use an assistant msg to improve long-context responses.
          if messages.last[:type] == :model && can_end_with_assistant_msg?
            messages = messages.dup
            messages.pop
          end

          trim_messages(messages).map { |msg| send("#{msg[:type]}_msg", msg) }.compact
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

        def tools_dialect
          @tools_dialect ||= DiscourseAi::Completions::Dialects::XmlTools.new(prompt.tools)
        end

        def system_msg(msg)
          raise NotImplemented
        end

        def assistant_msg(msg)
          raise NotImplemented
        end

        def user_msg(msg)
          raise NotImplemented
        end

        def tool_call_msg(msg)
          { role: "assistant", content: tools_dialect.from_raw_tool_call(msg) }
        end

        def tool_msg(msg)
          { role: "user", content: tools_dialect.from_raw_tool(msg) }
        end
      end
    end
  end
end
