# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class CannedResponse
        CANNED_RESPONSE_ERROR = Class.new(StandardError)

        def self.can_contact?(_)
          Rails.env.test?
        end

        def initialize(responses)
          @responses = responses
          @completions = 0
          @dialect = nil
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        attr_reader :responses, :completions, :dialect

        def prompt_messages
          dialect.prompt.messages
        end

        def perform_completion!(dialect, _user, _model_params, feature_name: nil)
          @dialect = dialect
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
            if is_tool?(response)
              yield(response, cancel_fn)
            else
              response.each_char do |char|
                break if cancelled
                yield(char, cancel_fn)
              end
            end
          else
            response
          end
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        private

        def is_tool?(response)
          Nokogiri::HTML5.fragment(response).at("function_calls").present?
        end
      end
    end
  end
end
