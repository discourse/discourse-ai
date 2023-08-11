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

        def summarize(content, &on_partial_blk)
          opts = content.except(:contents)

          {
            summary:
              completion_model.summarize_with_truncation(content[:contents], opts, &on_partial_blk),
            chunks: [],
          }
        end
      end
    end
  end
end
