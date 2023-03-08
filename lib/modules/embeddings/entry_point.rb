# frozen_string_literal: true

module DiscourseAI
  module Embeddings
    class EntryPoint
      def load_files
        require_relative "topic"
        require_relative "jobs/regular/generate_embeddings"
      end

      def inject_into(plugin)
        callback =
          Proc.new do |topic|
            if SiteSetting.ai_embeddings_enabled
              Jobs.enqueue(:generate_embeddings, topic_id: topic.id)
            end
          end

        plugin.on(:topic_created, &callback)
        plugin.on(:topic_edited, &callback)
      end
    end
  end
end
