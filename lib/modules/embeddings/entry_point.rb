# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EntryPoint
      def load_files
        require_relative "vector_representations/base"
        require_relative "vector_representations/all_mpnet_base_v2"
        require_relative "vector_representations/text_embedding_ada_002"
        require_relative "vector_representations/multilingual_e5_large"
        require_relative "vector_representations/bge_large_en"
        require_relative "strategies/truncation"
        require_relative "jobs/regular/generate_embeddings"
        require_relative "jobs/scheduled/embeddings_backfill"
        require_relative "semantic_related"
        require_relative "semantic_topic_query"

        require_relative "hyde_generators/base"
        require_relative "hyde_generators/openai"
        require_relative "hyde_generators/anthropic"
        require_relative "hyde_generators/llama2"
        require_relative "hyde_generators/llama2_ftos"
        require_relative "semantic_search"
      end

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

        # embeddings generation.
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
