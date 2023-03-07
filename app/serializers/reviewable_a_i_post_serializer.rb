# frozen_string_literal: true

class ReviewableAIPostSerializer < ReviewableFlaggedPostSerializer
  payload_attributes :accuracies
end
