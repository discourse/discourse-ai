# frozen_string_literal: true

Fabricator(:classification_result) do
  target { Fabricate(:post) }
  classification_type "sentiment"
end

Fabricator(:sentiment_classification, from: :classification_result) do
  model_used "sentiment"
  classification { { negative: 72, neutral: 23, positive: 4 } }
end

Fabricator(:emotion_classification, from: :classification_result) do
  model_used "emotion"
  classification { { negative: 72, neutral: 23, positive: 4 } }
end
