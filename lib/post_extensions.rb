# frozen_string_literal: true

module DiscourseAi
  module PostExtensions
    extend ActiveSupport::Concern

    prepended do
      has_many :classification_results, as: :target

      has_many :sentiment_classifications,
               -> { where(classification_type: "sentiment") },
               class_name: "ClassificationResult",
               as: :target
    end
  end
end
