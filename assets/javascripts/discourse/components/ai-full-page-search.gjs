import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { ajax } from "discourse/lib/ajax";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import icon from "discourse-common/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import AiIndicatorWave from "./ai-indicator-wave";

export default class AiFullPageSearch extends Component {
  @service appEvents;
  @service router;
  @service siteSettings;
  @service searchPreferencesManager;

  @tracked searching;
  @tracked AiResults = [];
  @tracked showingAiResults = false;
  @tracked sortOrder = this.args.sortOrder;
  initialSearchTerm = this.args.searchTerm;

  constructor() {
    super(...arguments);
    this.appEvents.on("full-page-search:trigger-search", this, this.onSearch);
    this.onSearch();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("full-page-search:trigger-search", this, this.onSearch);
  }

  @action
  onSearch() {
    if (!this.searchEnabled) {
      return;
    }

    this.initialSearchTerm = this.args.searchTerm;
    this.searching = true;
    this.resetAiResults();
    return this.performHyDESearch();
  }

  get disableToggleSwitch() {
    if (
      this.searching ||
      this.AiResults.length === 0 ||
      !this.validSearchOrder
    ) {
      return true;
    }
  }

  get validSearchOrder() {
    return this.sortOrder === 0;
  }

  get searchStateText() {
    if (!this.validSearchOrder) {
      return I18n.t(
        "discourse_ai.embeddings.semantic_search_results.unavailable"
      );
    }

    // Search loading:
    if (this.searching) {
      return I18n.t("discourse_ai.embeddings.semantic_search_loading");
    }

    // We have results and we are showing them
    if (this.AiResults.length && this.showingAiResults) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.toggle", {
        count: this.AiResults.length,
      });
    }

    // We have results but are hiding them
    if (this.AiResults.length && !this.showingAiResults) {
      return I18n.t(
        "discourse_ai.embeddings.semantic_search_results.toggle_hidden",
        {
          count: this.AiResults.length,
        }
      );
    }

    // Typing to search:
    if (
      this.AiResults.length === 0 &&
      this.searchTerm !== this.initialSearchTerm
    ) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.new");
    }

    // No results:
    if (this.AiResults.length === 0) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.none");
    }
  }

  get searchTerm() {
    if (this.initialSearchTerm !== this.args.searchTerm) {
      this.initialSearchTerm = undefined;
    }

    return this.args.searchTerm;
  }

  get searchEnabled() {
    return (
      this.args.searchType === SEARCH_TYPE_DEFAULT &&
      isValidSearchTerm(this.searchTerm, this.siteSettings) &&
      this.validSearchOrder
    );
  }

  get tooltipText() {
    return i18n(
      `discourse_ai.embeddings.semantic_search_tooltips.${
        this.validSearchOrder ? "results_explanation" : "invalid_sort"
      }`
    );
  }

  @action
  toggleAiResults() {
    if (this.showingAiResults) {
      this.args.addSearchResults([], "topic_id");
    } else {
      this.args.addSearchResults(this.AiResults, "topic_id");
    }
    this.showingAiResults = !this.showingAiResults;
  }

  @action
  resetAiResults() {
    this.AiResults = [];
    this.showingAiResults = false;
    this.args.addSearchResults([], "topic_id");
  }

  performHyDESearch() {
    this.resetAiResults();

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};

        if (model.posts?.length === 0) {
          return;
        }

        model.posts.forEach((post) => {
          post.generatedByAi = true;
        });

        this.AiResults = model.posts;
      })
      .finally(() => {
        this.searching = false;
      });
  }

  @action
  sortChanged() {
    if (this.sortOrder !== this.args.sortOrder) {
      this.sortOrder = this.args.sortOrder;

      if (this.validSearchOrder) {
        this.onSearch();
      } else {
        this.showingAiResults = false;
        this.resetAiResults();
      }
    }
  }

  <template>
    <span {{didUpdate this.sortChanged @sortOrder}}></span>
    <div class="semantic-search__container search-results" role="region">
      <div class="semantic-search__results">
        <div
          class="semantic-search__searching
            {{if this.searching 'in-progress'}}
            {{unless this.validSearchOrder 'unavailable'}}"
        >
          <DToggleSwitch
            disabled={{this.disableToggleSwitch}}
            @state={{this.showingAiResults}}
            class="semantic-search__results-toggle"
            {{on "click" this.toggleAiResults}}
          />

          <div class="semantic-search__searching-text">
            {{icon "discourse-sparkles"}}
            {{this.searchStateText}}
          </div>

          {{#if this.validSearchOrder}}
            <AiIndicatorWave @loading={{this.searching}} />
          {{/if}}

          <DTooltip
            @identifier="semantic-search-tooltip"
            class="semantic-search__tooltip"
          >
            <:trigger>
              {{icon "far-circle-question"}}
            </:trigger>
            <:content>
              {{this.tooltipText}}
            </:content>
          </DTooltip>
        </div>
      </div>
    </div>
  </template>
}
