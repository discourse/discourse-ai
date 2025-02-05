# frozen_string_literal: true

module DiscourseAi
  module Sentiment
    class SentimentAnalysisReport
      def self.register!(plugin)
        plugin.add_report("sentiment_analysis") do |report|
          # TODO: Implement the report
          report.modes = [:sentiment_analysis]
          report.data = [300, 50, 100]
        end
      end
    end
  end
end
