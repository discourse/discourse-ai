import Component from "@glimmer/component";
import { action } from "@ember/object";
import I18n from "I18n";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { isValidSearchTerm, translateResults } from "discourse/lib/search";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { withPluginApi } from "discourse/lib/plugin-api";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import icon from "discourse-common/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class SemanticSearch extends Component {
  <template>
    {{#if this.searchEnabled}}
      <div class="semantic-search__container search-results" role="region">
        <div
          class="semantic-search__results"
          {{didInsert this.setup}}
          {{didInsert this.debouncedSearch}}
          {{willDestroy this.teardown}}
        >
          <div
            class="semantic-search__searching {{if this.searching 'in-progress'}}"
          >
            <DToggleSwitch
              disabled={{this.searching}}
              @state={{this.showingAIResults}}
              title="AI search results hidden"
              class="semantic-search__results-toggle"
              {{on "click" this.toggleAIResults}}
            />
            
            <div class="semantic-search__searching-text">
              {{icon "discourse-sparkles"}}
              {{this.searchStateText}}
            </div>

            {{#if this.searching}}
              <span class="semantic-search__indicator-wave">
                <span class="semantic-search__indicator-dot">.</span>
                <span class="semantic-search__indicator-dot">.</span>
                <span class="semantic-search__indicator-dot">.</span>
              </span>
            {{/if}}
          </div>
        </div>
      </div>
    {{/if}}
  </template>

  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  @service appEvents;
  @service siteSettings;

  @tracked searching = true;
  @tracked AIResults = [];
  @tracked showingAIResults = false;

  get searchStateText() {
    if (this.searching) {
      return I18n.t("discourse_ai.embeddings.semantic_search_loading");
    }

    if (this.AIResults.length === 0) {
      return I18n.t("discourse_ai.embeddings.semantic_search_results.none");
    }

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
  }

  get searchTerm() {
    return this.args.outletArgs.search;
  }

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
  resetAIResults() {
    this.AIResults = [];
    this.showingAIResults = false;
    document.body.classList.remove("showing-ai-results");
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
    this.resetAIResults();

    ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: this.searchTerm },
    })
      .then(async (results) => {
        const model = (await translateResults(results)) || {};
          const AIResults = model.posts.map(function (post) {
            return Object.assign({}, post, { generatedByAI: true });
          });

          this.args.outletArgs.addSearchResults(AIResults);
          this.AIResults = AIResults;
      })
      .catch(popupAjaxError)
      .finally(() => (this.searching = false));
  }

  @action
  debouncedSearch() {
    discourseDebounce(this, this.performHyDESearch, 500);
  }
}
