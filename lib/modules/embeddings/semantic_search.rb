# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSearch
      def self.clear_cache_for(query)
        digest = OpenSSL::Digest::SHA1.hexdigest(query)

        Discourse.cache.delete("hyde-doc-#{digest}")
        Discourse.cache.delete("hyde-doc-embedding-#{digest}")
      end

      def initialize(guardian)
        @guardian = guardian
      end

      def search_for_topics(query, page = 1)
        max_results_per_page = 50
        limit = [Search.per_filter, max_results_per_page].min + 1
        offset = (page - 1) * limit

        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

        digest = OpenSSL::Digest::SHA1.hexdigest(query)

        hypothetical_post =
          Discourse
            .cache
            .fetch("hyde-doc-#{digest}", expires_in: 1.week) do
              hyde_generator = DiscourseAi::Embeddings::HydeGenerators::Base.current_hyde_model.new
              hyde_generator.hypothetical_post_from(query)
            end

        hypothetical_post_embedding =
          Discourse
            .cache
            .fetch("hyde-doc-embedding-#{digest}", expires_in: 1.week) do
              vector_rep.vector_from(hypothetical_post)
            end

        candidate_topic_ids =
          vector_rep.asymmetric_topics_similarity_search(
            hypothetical_post_embedding,
            limit: limit,
            offset: offset,
          )

        ::Post
          .where(post_type: ::Topic.visible_post_types(guardian.user))
          .public_posts
          .where("topics.visible")
          .where(topic_id: candidate_ids, post_number: 1)
          .order("array_position(ARRAY#{candidate_ids}, topic_id)")
      end

      private

      attr_reader :guardian
    end
  end
end
