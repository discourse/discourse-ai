# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class CannedResponse
        CANNED_RESPONSE_ERROR = Class.new(StandardError)

        def initialize(responses)
          @responses = responses
          @completions = 0
          @dialect = nil
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        attr_reader :responses, :completions, :dialect, :model_params

        def prompt_messages
          dialect.prompt.messages
        end

        def perform_completion!(
          dialect,
          _user,
          model_params,
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false
        )
          @dialect = dialect
          @model_params = model_params
          response = responses[completions]
          if response.nil?
            raise CANNED_RESPONSE_ERROR,
                  "The number of completions you requested exceed the number of canned responses"
          end

          raise response if response.is_a?(StandardError)

          @completions += 1
          if block_given?
            cancelled = false
            cancel_fn = lambda { cancelled = true }

            # We buffer and return tool invocations in one go.
            as_array = response.is_a?(Array) ? response : [response]
            as_array.each do |response|
              if is_tool?(response)
                yield(response, cancel_fn)
              elsif is_thinking?(response)
                yield(response, cancel_fn)
              else
                response.each_char do |char|
                  break if cancelled
                  yield(char, cancel_fn)
                end
              end
            end
          end

          response = response.first if response.is_a?(Array) && response.length == 1
          response
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        private

        def is_thinking?(response)
          response.is_a?(DiscourseAi::Completions::Thinking)
        end

        def is_tool?(response)
          response.is_a?(DiscourseAi::Completions::ToolCall)
        end
      end
    end
  end
end
