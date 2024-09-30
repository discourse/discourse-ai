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
        Discourse.cache.delete("-#{SiteSetting.ai_embeddings_model}")
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

      def vector_rep
        @vector_rep ||=
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(
            DiscourseAi::Embeddings::Strategies::Truncation.new,
          )
      end

      def hyde_embedding(search_term)
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

        Discourse
          .cache
          .fetch(embedding_key, expires_in: 1.week) { vector_rep.vector_from(hypothetical_post) }
      end

      def embedding(search_term)
        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)
        embedding_key = build_embedding_key(digest, "", SiteSetting.ai_embeddings_model)

        Discourse
          .cache
          .fetch(embedding_key, expires_in: 1.week) { vector_rep.vector_from(search_term) }
      end

      # this ensures the candidate topics are over selected
      # that way we have a much better chance of finding topics
      # if the user filtered the results or index is a bit out of date
      OVER_SELECTION_FACTOR = 4

      def search_for_topics(query, page = 1, hyde: true)
        max_results_per_page = 100
        limit = [Search.per_filter, max_results_per_page].min + 1
        offset = (page - 1) * limit
        search = Search.new(query, { guardian: guardian })
        search_term = search.term

        return [] if search_term.nil? || search_term.length < SiteSetting.min_search_term_length

        search_embedding = hyde ? hyde_embedding(search_term) : embedding(search_term)

        over_selection_limit = limit * OVER_SELECTION_FACTOR

        candidate_topic_ids =
          vector_rep.asymmetric_topics_similarity_search(
            search_embedding,
            limit: over_selection_limit,
            offset: offset,
          )

        semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(topic_id: candidate_topic_ids, post_number: 1)
            .order("array_position(ARRAY#{candidate_topic_ids}, posts.topic_id)")
            .limit(limit)

        query_filter_results = search.apply_filters(semantic_results)

        guardian.filter_allowed_categories(query_filter_results)
      end

      def quick_search(query)
        max_semantic_results_per_page = 100
        search = Search.new(query, { guardian: guardian })
        search_term = search.term

        return [] if search_term.nil? || search_term.length < SiteSetting.min_search_term_length

        strategy = DiscourseAi::Embeddings::Strategies::Truncation.new
        vector_rep =
          DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(strategy)

        digest = OpenSSL::Digest::SHA1.hexdigest(search_term)

        embedding_key =
          build_embedding_key(
            digest,
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
            SiteSetting.ai_embeddings_model,
          )

        search_term_embedding =
          Discourse
            .cache
            .fetch(embedding_key, expires_in: 1.week) do
              vector_rep.vector_from(search_term, asymetric: true)
            end

        candidate_post_ids =
          vector_rep.asymmetric_posts_similarity_search(
            search_term_embedding,
            limit: max_semantic_results_per_page,
            offset: 0,
          )

        semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(id: candidate_post_ids)
            .order("array_position(ARRAY#{candidate_post_ids}, posts.id)")

        filtered_results = search.apply_filters(semantic_results)

        rerank_posts_payload =
          filtered_results
            .map(&:cooked)
            .map { Nokogiri::HTML5.fragment(_1).text }
            .map { _1.truncate(2000, omission: "") }

        reranked_results =
          DiscourseAi::Inference::HuggingFaceTextEmbeddings.rerank(
            search_term,
            rerank_posts_payload,
          )

        reordered_ids = reranked_results.map { _1[:index] }.map { filtered_results[_1].id }.take(5)

        reranked_semantic_results =
          ::Post
            .where(post_type: ::Topic.visible_post_types(guardian.user))
            .public_posts
            .where("topics.visible")
            .where(id: reordered_ids)
            .order("array_position(ARRAY#{reordered_ids}, posts.id)")

        guardian.filter_allowed_categories(reranked_semantic_results)
      end

      def hypothetical_post_from(search_term)
        prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
          You are a content creator for a forum. The forum description is as follows:
          #{SiteSetting.title}
          #{SiteSetting.site_description}

          Put the forum post between <ai></ai> tags.
        TEXT

        prompt.push(type: :user, content: <<~TEXT.strip)
          Using this description, write a forum post about the subject inside the <input></input> XML tags:

          <input>#{search_term}</input>
        TEXT

        llm_response =
          DiscourseAi::Completions::Llm.proxy(
            SiteSetting.ai_embeddings_semantic_search_hyde_model,
          ).generate(prompt, user: @guardian.user, feature_name: "semantic_search_hyde")

        Nokogiri::HTML5.fragment(llm_response).at("ai")&.text.presence || llm_response
      end

      private

      attr_reader :guardian

      def build_hyde_key(digest, hyde_model)
        "semantic-search-#{digest}-#{hyde_model}"
      end

      def build_embedding_key(digest, hyde_model, embedding_model)
        "#{build_hyde_key(digest, hyde_model)}-#{embedding_model}"
      end
    end
  end
end
