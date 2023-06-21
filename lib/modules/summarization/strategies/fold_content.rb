# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class FoldContent < ::Summarization::Base
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
          summaries = completion_model.summarize_in_chunks(content[:contents], opts)

          return { summary: summaries.first[:summary], chunks: [] } if summaries.length == 1

          { summary: completion_model.concatenate_summaries(summaries), chunks: summaries }
        end
      end
    end
  end
end
