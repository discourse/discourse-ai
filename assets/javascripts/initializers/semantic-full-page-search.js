import { withPluginApi } from "discourse/lib/plugin-api";
import { translateResults, updateRecentSearches } from "discourse/lib/search";
import { ajax } from "discourse/lib/ajax";

const SEMANTIC_SEARCH = "semantic_search";

function initializeSemanticSearch(api) {
  api.addFullPageSearchType(
    "discourse_ai.embeddings.semantic_search",
    SEMANTIC_SEARCH,
    (searchController, args) => {
      if (searchController.currentUser) {
        updateRecentSearches(searchController.currentUser, args.searchTerm);
      }

      ajax("/discourse-ai/embeddings/semantic-search", { data: args })
        .then(async (results) => {
          const model = (await translateResults(results)) || {};

          if (results.grouped_search_result) {
            searchController.set("q", results.grouped_search_result.term);
          }

          if (args.page > 1) {
            if (model) {
              searchController.model.posts.pushObjects(model.posts);
              searchController.model.topics.pushObjects(model.topics);
              searchController.model.set(
                "grouped_search_result",
                results.grouped_search_result
              );
            }
          } else {
            model.grouped_search_result = results.grouped_search_result;
            searchController.set("model", model);
          }
          searchController.set("error", null);
        })
        .catch((e) => {
          searchController.set("error", e.jqXHR.responseJSON?.message);
        })
        .finally(() => {
          searchController.setProperties({
            searching: false,
            loading: false,
          });
        });
    }
  );
}

export default {
  name: "discourse_ai-full-page-semantic-search",

  initialize(container) {
    const settings = container.lookup("site-settings:main");

    if (settings.ai_embeddings_enabled) {
      withPluginApi("1.6.0", initializeSemanticSearch);
    }
  },
};
