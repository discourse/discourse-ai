# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EntryPoint
      def inject_into(plugin)
        # Include random topics in the suggested list *only* if there are no related topics.
        plugin.register_modifier(
          :topic_view_suggested_topics_options,
        ) do |suggested_options, topic_view|
          related_topics = topic_view.related_topics
          include_random = related_topics.nil? || related_topics.length == 0
          suggested_options.merge(include_random: include_random)
        end

        # Query and serialize related topics.
        plugin.add_to_class(:topic_view, :related_topics) do
          if topic.private_message? || !SiteSetting.ai_embeddings_semantic_related_topics_enabled
            return nil
          end

          @related_topics ||=
            SemanticTopicQuery.new(@user).list_semantic_related_topics(topic).topics
        end

        %i[topic_view TopicViewPosts].each do |serializer|
          plugin.add_to_serializer(
            serializer,
            :related_topics,
            include_condition: -> { SiteSetting.ai_embeddings_semantic_related_topics_enabled },
          ) do
            if object.next_page.nil? && !object.topic.private_message?
              object.related_topics.map do |t|
                SuggestedTopicSerializer.new(t, scope: scope, root: false)
              end
            end
          end
        end

        plugin.register_html_builder("server:topic-show-after-posts-crawler") do |controller|
          SemanticRelated.related_topics_for_crawler(controller)
        end

        # embeddings generation.
        callback =
          Proc.new do |target|
            if SiteSetting.ai_embeddings_enabled
              Jobs.enqueue(:generate_embeddings, target_id: target.id, target_type: target.class.name)
            end
          end

        plugin.on(:topic_created, &callback)
        plugin.on(:topic_edited, &callback)
        plugin.on(:post_created, &callback)
        plugin.on(:post_edited, &callback)
      end
    end
  end
end
