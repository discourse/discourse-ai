# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    module TopicViewSerializerAdditions
      def include_related_topics?
        SiteSetting.ai_embeddings_semantic_suggested_topics_enabled
      end

      def related_topics
        if object.next_page.nil? && !object.topic.private_message? && scope.authenticated?
          @related_topics ||=
            TopicList.new(
              :suggested,
              nil,
              DiscourseAi::Embeddings::SemanticSuggested.candidates_for(object.topic),
            ).topics
        end
      end

      def suggested_topics
        if !SiteSetting.ai_embeddings_semantic_suggested_topics_enabled ||
             object.topic.private_message?
          super
        else
          if object.next_page.nil?
            @suggested_topics ||=
              TopicQuery
                .new(@user)
                .list_suggested_for(
                  topic,
                  include_random:
                    !SiteSetting.ai_embeddings_semantic_suggested_topics_enabled ||
                      related_topics.length == 0,
                )
                .topics
          end
        end
      end
    end

    class EntryPoint
      def load_files
        require_relative "models"
        require_relative "topic"
        require_relative "jobs/regular/generate_embeddings"
        require_relative "semantic_suggested"
      end

      def inject_into(plugin)
        TopicViewSerializer.attribute :related_topics
        TopicViewPostsSerializer.attribute :related_topics
        TopicViewSerializer.prepend(TopicViewSerializerAdditions)
        TopicViewPostsSerializer.prepend(TopicViewSerializerAdditions)

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
