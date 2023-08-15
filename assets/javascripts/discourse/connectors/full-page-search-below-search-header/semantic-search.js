import Component from "@glimmer/component";
import { action, computed } from "@ember/object";
import I18n from "I18n";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { translateResults } from "discourse/lib/search";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";

export default class extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  @service appEvents;

  @tracked searching = false;
  @tracked collapsedResults = true;
  @tracked results = [];

  @computed("args.outletArgs.search")
  get searchTerm() {
    return this.args.outletArgs.search;
  }

  @computed("args.outletArgs.type")
  get searchEnabled() {
    return this.args.outletArgs.type === SEARCH_TYPE_DEFAULT;
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
    if (!this.searchTerm || !this.searchEnabled || this.searching) {
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
