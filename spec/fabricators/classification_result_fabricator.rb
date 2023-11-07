# frozen_string_literal: true

Fabricator(:classification_result) { target { Fabricate(:post) } }

Fabricator(:sentiment_classification, from: :classification_result) do
  classification_type "sentiment"
  classification { { negative: 72, neutral: 23, positive: 4 } }
end

Fabricator(:emotion_classification, from: :classification_result) do
  classification_type "emotion"
  classification { { negative: 72, neutral: 23, positive: 4 } }
end
