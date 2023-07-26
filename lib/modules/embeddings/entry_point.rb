# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EntryPoint
      def load_files
        require_relative "models/base"
        require_relative "models/all_mpnet_base_v2"
        require_relative "models/text_embedding_ada_002"
        require_relative "models/multilingual_e5_large"
        require_relative "strategies/truncation"
        require_relative "manager"
        require_relative "jobs/regular/generate_embeddings"
        require_relative "semantic_related"
        require_relative "semantic_search"
      end

      def inject_into(plugin)
        plugin.add_to_class(:topic_view, :related_topics) do
          if topic.private_message? || !SiteSetting.ai_embeddings_semantic_related_topics_enabled
            return nil
          end

          @related_topics ||=
            TopicList.new(
              :suggested,
              nil,
              DiscourseAi::Embeddings::SemanticRelated.candidates_for(topic),
            ).topics
        end

        plugin.register_modifier(
          :topic_view_suggested_topics_options,
        ) do |suggested_options, topic_view|
          related_topics = topic_view.related_topics
          include_random = related_topics.nil? || related_topics.length == 0
          suggested_options.merge(include_random: include_random)
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
