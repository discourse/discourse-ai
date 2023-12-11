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
          @prompt = nil
        end

        attr_reader :responses, :completions, :prompt

        def perform_completion!(prompt, _user, _model_params)
          @prompt = prompt
          response = responses[completions]
          if response.nil?
            raise CANNED_RESPONSE_ERROR,
                  "The number of completions you requested exceed the number of canned responses"
          end

          @completions += 1
          if block_given?
            cancelled = false
            cancel_fn = lambda { cancelled = true }

            response.each_char do |char|
              break if cancelled
              yield(char, cancel_fn)
            end
          else
            response
          end
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
