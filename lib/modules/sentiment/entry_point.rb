# frozen_string_literal: true
module DiscourseAI
  module Sentiment
    class EntryPoint
      def inject_into(plugin)
        require_relative "event_handler.rb"
        require_relative "post_classifier.rb"
        require_relative "../../../app/jobs/regular/modules/sentiment/sentiment_classify_post.rb"

        plugin.on(:post_created) do |post|
          DiscourseAI::Sentiment::EventHandler.handle_post_async(post)
        end

        plugin.on(:post_edited) do |post|
          DiscourseAI::Sentiment::EventHandler.handle_post_async(post)
        end
      end
    end
  end
end
