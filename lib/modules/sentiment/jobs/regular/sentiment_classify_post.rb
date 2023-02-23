# frozen_string_literal: true

module ::Jobs
  class SentimentClassifyPost < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.ai_sentiment_enabled

      post_id = args[:post_id]
      return if post_id.blank?

      post = Post.find_by(id: post_id, post_type: Post.types[:regular])
      return if post&.raw.blank?

      ::DiscourseAI::Sentiment::PostClassifier.new(post).classify!
    end
  end
end
