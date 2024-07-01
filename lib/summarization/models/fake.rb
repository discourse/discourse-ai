# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Fake < Base
        def display_name
          "fake"
        end

        def correctly_configured?
          true
        end

        def configuration_hint
          ""
        end

        def model
          "fake"
        end
      end
    end
  end
end
