# frozen_string_literal: true

module DiscourseAI
  module Embeddings
    class EntryPoint
      def load_files
        require_relative "topic"
        require_relative "jobs/regular/generate_embeddings"
        require_relative "semantic_suggested"
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

        DiscoursePluginRegistry.register_list_suggested_for_provider(
          SemanticSuggested.method(:build_suggested_topics),
          plugin,
        )
      end
    end
  end
end
