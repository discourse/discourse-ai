import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import i18n from "discourse-common/helpers/i18n";

export default class AiQuickSemanticSearch extends Component {
  @service search;

  @action
  searchTermChanged() {
    // todo handle the HyDE search
    // console.log("searchTermChanged", this);
  }

  <template>
    {{yield}}

    {{#if this.search.activeGlobalSearchTerm}}
      <AssistantItem
        @suffix={{i18n "discourse_ai.embeddings.quick_search.suffix"}}
        @icon="discourse-sparkles"
        @slug={{this.slug}}
        @closeSearchMenu={{@closeSearchMenu}}
        @searchTermChanged={{this.searchTermChanged}}
        @suggestionKeyword={{@suggestionKeyword}}
      />
    {{/if}}
  </template>
}
