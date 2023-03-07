# frozen_string_literal: true

class ReviewableAIChatMessageSerializer < ReviewableChatMessageSerializer
  payload_attributes :accuracies
end
