# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class CannedResponse
        def self.can_contact?(_)
          Rails.env.test?
        end

        def initialize(response)
          @response = response
        end

        attr_reader :response

        def perform_completion!(_prompt, _user, _model_params)
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
      end
    end
  end
end
