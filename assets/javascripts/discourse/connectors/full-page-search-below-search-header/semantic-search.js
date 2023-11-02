import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import I18n from "I18n";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed from "discourse-common/utils/decorators";

export default class SemanticSearch extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  @service appEvents;
  @service siteSettings;

  @tracked searching = true;
  @tracked results = [];
  @tracked showingAIResults = false;
  get searchStateText() {
    if (this.searching) {
      return I18n.t("discourse_ai.embeddings.semantic_search_loading");
    }

    if (this.results.length === 0) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.none");
    }

    if (this.results.length > 0) {
      if (this.showingAIResults) {
        return I18n.t(
          "discourse_ai.embeddings.semantic_search_results.toggle",
          {
            count: this.results.length,
          }
        );
      } else {
        return I18n.t(
          "discourse_ai.embeddings.semantic_search_results.toggle_hidden",
          {
            count: this.results.length,
          }
        );
      }
    }
  }

  @computed("args.outletArgs.search")
  get searchTerm() {
    return this.args.outletArgs.search;
  }

  @computed("args.outletArgs.type", "searchTerm")
  get searchEnabled() {
    return (
      this.args.outletArgs.type === SEARCH_TYPE_DEFAULT &&
      isValidSearchTerm(this.searchTerm, this.siteSettings)
    );
  }

  @action
  toggleAIResults() {
    document.body.classList.toggle("showing-ai-results");
    this.showingAIResults = !this.showingAIResults;
  }

  @action
  setup() {
    this.appEvents.on(
      "full-page-search:trigger-search",
      this,
      "debouncedSearch"
    );
  }

  @action
  teardown() {
    this.appEvents.off(
      "full-page-search:trigger-search",
      this,
      "debouncedSearch"
    );
  }

  @bind
  performHyDESearch() {
    if (!this.searchEnabled) {
      return;
    }

    this.searching = true;
    this.showingAIResults = false;
    this.results = [];

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};
        withPluginApi("1.6.0", (api) => {
          console.log("Reached dawg", model.posts);

          const AIResults = model.posts.map(function (post) {
            return Object.assign({}, post, { generatedByAI: true });
          });

          // TODO: this feels like it should be done
          // automatically by the pluginAPI or within full-page-search.
          // Is there a better way to do this without needing to getOwner
          // get controller and thereby introduce code smell?

          api.addSearchResults(AIResults);
          this.results = AIResults;
        });
      })
      // TODO handle error in ui
      .catch((e) => console.log(e))
      .finally(() => (this.searching = false));
  }

  @action
  debouncedSearch() {
    discourseDebounce(this, this.performHyDESearch, 500);
  }
}
