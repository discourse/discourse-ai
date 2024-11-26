# frozen_string_literal: true

module DiscourseAi
  module TopicExtensions
    extend ActiveSupport::Concern

    prepended do
      has_many :ai_summaries, as: :target

      has_one :ai_gist_summary,
              -> { where(summary_type: AiSummary.summary_types[:gist]) },
              class_name: "AiSummary",
              as: :target
    end
  end
end
