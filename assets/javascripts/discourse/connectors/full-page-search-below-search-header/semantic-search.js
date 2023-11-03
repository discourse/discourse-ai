import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { ajax } from "discourse/lib/ajax";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";

export default class extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  @service appEvents;
  @service siteSettings;

  @tracked searching = true;
  @tracked collapsedResults = true;
  @tracked results = [];

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

  @computed("results")
  get collapsedResultsTitle() {
    return I18n.t("discourse_ai.embeddings.semantic_search_results.toggle", {
      count: this.results.length,
    });
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
    this.collapsedResults = true;
    this.results = [];

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};
        this.results = model.posts;
      })
      .finally(() => (this.searching = false));
  }

  @action
  debouncedSearch() {
    discourseDebounce(this, this.performHyDESearch, 500);
  }
}
