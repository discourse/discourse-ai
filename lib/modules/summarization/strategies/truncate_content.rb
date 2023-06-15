# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class TruncateContent < ::Summarization::Base
        def initialize(completion_model)
          @completion_model = completion_model
        end

        attr_reader :completion_model

        delegate :correctly_configured?,
                 :display_name,
                 :configuration_hint,
                 :model,
                 to: :completion_model

        def summarize(content)
          opts = content.except(:contents)
          completion_model.summarize_with_truncation(content[:contents], opts)
        end
      end
    end
  end
end
