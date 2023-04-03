# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class EmbeddingsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      SEMANTIC_SEARCH_TYPE = "semantic_search"

      def search
        query = params[:q]
        page = (params[:page] || 1).to_i

        grouped_results =
          Search::GroupedSearchResults.new(
            type_filter: SEMANTIC_SEARCH_TYPE,
            term: query,
            search_context: guardian,
            use_pg_headlines_for_excerpt: false,
          )

        model =
          DiscourseAi::Embeddings::Model.instantiate(
            SiteSetting.ai_embeddings_semantic_search_model,
          )

        DiscourseAi::Embeddings::SemanticSearch
          .new(guardian, model)
          .search_for_topics(query, page)
          .each { |topic_post| grouped_results.add(topic_post) }

        render_serialized(grouped_results, GroupedSearchResultSerializer, result: grouped_results)
      end
    end
  end
end
