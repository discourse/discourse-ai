# frozen_string_literal: true
module DiscourseAI
  module Toxicity
    class EntryPoint
      def load_files
        require_relative "scan_queue"
        require_relative "toxicity_classification"

        require_relative "jobs/regular/toxicity_classify_post"
        require_relative "jobs/regular/toxicity_classify_chat_message"
      end

      def inject_into(plugin)
        post_analysis_cb = Proc.new { |post| DiscourseAI::Toxicity::ScanQueue.enqueue_post(post) }

        plugin.on(:post_created, &post_analysis_cb)
        plugin.on(:post_edited, &post_analysis_cb)

        chat_message_analysis_cb =
          Proc.new { |message| DiscourseAI::Toxicity::ScanQueue.enqueue_chat_message(message) }

        plugin.on(:chat_message_created, &chat_message_analysis_cb)
        plugin.on(:chat_message_edited, &chat_message_analysis_cb)
      end
    end
  end
end
