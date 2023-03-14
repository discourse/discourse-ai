# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EntryPoint
      def load_files
        require_relative "sentiment_classification"
        require_relative "jobs/regular/post_sentiment_analysis"
      end

      def inject_into(plugin)
        sentiment_analysis_cb =
          Proc.new do |post|
            if SiteSetting.ai_sentiment_enabled
              Jobs.enqueue(:post_sentiment_analysis, post_id: post.id)
            end
          end

        plugin.on(:post_created, &sentiment_analysis_cb)
        plugin.on(:post_edited, &sentiment_analysis_cb)
      end
    end
  end
end
