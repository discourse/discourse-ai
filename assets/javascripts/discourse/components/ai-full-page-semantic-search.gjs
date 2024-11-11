import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";
import AiIndicatorWave from "./ai-indicator-wave";

export default class AiFullPageSemanticSearch extends Component {
  @service appEvents;
  @service siteSettings;
  @service searchPreferencesManager;

  @tracked searching = false;
  @tracked AIResults = [];
  @tracked showingAIResults = false;
  initialSearchTerm = this.args.outletArgs.search;

  get disableToggleSwitch() {
    if (
      this.searching ||
      this.AIResults.length === 0 ||
      this.args.outletArgs.sortOrder !== 0
    ) {
      return true;
    }
  }

  get searchStateText() {
    // Search results:
    if (this.AIResults.length > 0) {
      if (this.showingAIResults) {
        return I18n.t(
          "discourse_ai.embeddings.semantic_search_results.toggle",
          {
            count: this.AIResults.length,
          }
        );
      } else {
        return I18n.t(
          "discourse_ai.embeddings.semantic_search_results.toggle_hidden",
          {
            count: this.AIResults.length,
          }
        );
      }
    }

    // Search loading:
    if (this.searching) {
      return I18n.t("discourse_ai.embeddings.semantic_search_loading");
    }

    // Typing to search:
    if (
      this.AIResults.length === 0 &&
      this.searchTerm !== this.initialSearchTerm
    ) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.new");
    }

    // No results:
    if (this.AIResults.length === 0) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.none");
    }
  }

  get searchTerm() {
    if (this.initialSearchTerm !== this.args.outletArgs.search) {
      this.initialSearchTerm = undefined;
    }

    return this.args.outletArgs.search;
  }

  get searchEnabled() {
    return (
      this.args.outletArgs.type === SEARCH_TYPE_DEFAULT &&
      isValidSearchTerm(this.searchTerm, this.siteSettings) &&
      this.args.outletArgs.sortOrder === 0
    );
  }

  @action
  toggleAIResults() {
    if (this.showingAIResults) {
      this.args.outletArgs.addSearchResults([], "topic_id");
    } else {
      this.args.outletArgs.addSearchResults(this.AIResults, "topic_id");
    }
    this.showingAIResults = !this.showingAIResults;
  }

  @action
  resetAIResults() {
    this.AIResults = [];
    this.showingAIResults = false;
    this.args.outletArgs.addSearchResults([], "topic_id");
  }

  @action
  handleSearch() {
    if (!this.searchEnabled) {
      return;
    }

    if (this.initialSearchTerm && !this.searching) {
      return this.performHyDESearch();
    }

    withPluginApi("1.15.0", (api) => {
      api.onAppEvent("full-page-search:trigger-search", () => {
        if (!this.searching) {
          this.resetAIResults();
          return this.performHyDESearch();
        }
      });
    });
  }

  performHyDESearch() {
    this.searching = true;
    this.resetAIResults();

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};

        if (model.posts?.length === 0) {
          this.searching = false;
          return;
        }

        model.posts.forEach((post) => {
          post.generatedByAI = true;
        });

        this.AIResults = model.posts;
      })
      .finally(() => (this.searching = false));
  }

  <template>
    {{#if this.searchEnabled}}
      <div class="semantic-search__container search-results" role="region">
        <div class="semantic-search__results" {{didInsert this.handleSearch}}>
          <div
            class="semantic-search__searching
              {{if this.searching 'in-progress'}}"
          >
            <DToggleSwitch
              disabled={{this.disableToggleSwitch}}
              @state={{this.showingAIResults}}
              title="AI search results hidden"
              class="semantic-search__results-toggle"
              {{on "click" this.toggleAIResults}}
            />

            <div class="semantic-search__searching-text">
              {{icon "discourse-sparkles"}}
              {{this.searchStateText}}
            </div>

            <AiIndicatorWave @loading={{this.searching}} />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
