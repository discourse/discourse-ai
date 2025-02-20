# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class EntryPoint
      def inject_into(plugin)
        sentiment_analysis_cb =
          Proc.new do |post|
            if SiteSetting.ai_sentiment_enabled
              Jobs.enqueue(:post_sentiment_analysis, post_id: post.id)
            end
          end

        plugin.on(:post_created, &sentiment_analysis_cb)
        plugin.on(:post_edited, &sentiment_analysis_cb)

        additional_icons = %w[face-smile face-meh face-angry]
        additional_icons.each { |icon| plugin.register_svg_icon(icon) }

        EmotionFilterOrder.register!(plugin)
        EmotionDashboardReport.register!(plugin)
        SentimentDashboardReport.register!(plugin)
        SentimentAnalysisReport.register!(plugin)
      end
    end
  end
end
