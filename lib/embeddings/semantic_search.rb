# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class SemanticSearch
      def self.clear_cache_for(query)
        digest = OpenSSL::Digest::SHA1.hexdigest(query)

        hyde_key =
          "semantic-search-#{digest}-#{SiteSetting.ai_embeddings_semantic_search_hyde_model}"

        Discourse.cache.delete(hyde_key)
        Discourse.cache.delete("#{hyde_key}-#{SiteSetting.ai_embeddings_model}")
      end

      def initialize(guardian)
        @guardian = guardian
      end

      def cached_query?(query)
        digest = OpenSSL::Digest::SHA1.hexdigest(query)
        embedding_key =
          build_embedding_key(
            digest,
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
            SiteSetting.ai_embeddings_model,
          )

        Discourse.cache.read(embedding_key).present?
      end

      def search_for_topics(query, page = 1)
        max_results_per_page = 100
        limit = [Search.per_filter, max_results_per_page].min + 1
        offset = (page - 1) * limit
        search = Search.new(query, { guardian: guardian })
        search_term = search.term

        return [] if search_term.nil? || search_term.length < SiteSetting.min_search_term_length

        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)
        hyde_key = build_hyde_key(digest, SiteSetting.ai_embeddings_semantic_search_hyde_model)

        embedding_key =
          build_embedding_key(
            digest,
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
            SiteSetting.ai_embeddings_model,
          )

        hypothetical_post =
          Discourse
            .cache
            .fetch(hyde_key, expires_in: 1.week) { hypothetical_post_from(search_term) }

        hypothetical_post_embedding =
          Discourse
            .cache
            .fetch(embedding_key, expires_in: 1.week) { vector_rep.vector_from(hypothetical_post) }

        candidate_topic_ids =
          vector_rep.asymmetric_topics_similarity_search(
            hypothetical_post_embedding,
            limit: limit,
            offset: offset,
          )

        semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(topic_id: candidate_topic_ids, post_number: 1)
            .order("array_position(ARRAY#{candidate_topic_ids}, topic_id)")

        query_filter_results = search.apply_filters(semantic_results)

        guardian.filter_allowed_categories(query_filter_results)
      end

      private

      attr_reader :guardian

      def build_hyde_key(digest, hyde_model)
        "semantic-search-#{digest}-#{hyde_model}"
      end

      def build_embedding_key(digest, hyde_model, embedding_model)
        "#{build_hyde_key(digest, hyde_model)}-#{embedding_model}"
      end

      def hypothetical_post_from(search_term)
        prompt = {
          insts: <<~TEXT,
          You are a content creator for a forum. The forum description is as follows:
          #{SiteSetting.title}
          #{SiteSetting.site_description}
        TEXT
          input: <<~TEXT,
          Using this description, write a forum post about the subject inside the <input></input> XML tags:

          <input>#{search_term}</input>
        TEXT
          post_insts: "Put the forum post between <ai></ai> tags.",
        }

        llm_response =
          DiscourseAi::Completions::Llm.proxy(
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
          ).completion!(prompt, @guardian.user)

        Nokogiri::HTML5.fragment(llm_response).at("ai").text.presence || llm_response
      end
    end
  end
end
