# frozen_string_literal: true

module ::DiscourseAI
  module Sentiment
    class EventHandler
      class << self
        def handle_post_async(post)
          return unless SiteSetting.ai_sentiment_enabled
          Jobs.enqueue(:sentiment_classify_post, post_id: post.id)
        end
      end
    end
  end
end
