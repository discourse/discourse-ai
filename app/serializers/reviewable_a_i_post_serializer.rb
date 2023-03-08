# frozen_string_literal: true

require_dependency "reviewable_flagged_post_serializer"

class ReviewableAIPostSerializer < ReviewableFlaggedPostSerializer
  payload_attributes :accuracies
end
