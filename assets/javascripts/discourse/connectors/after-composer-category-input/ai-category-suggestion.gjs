import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import { showComposerAIHelper } from "../../lib/show-ai-helper";

export default class AiCategorySuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAIHelper(outletArgs, helper);
  }

  @service siteSettings;

  <template>
    {{#if this.siteSettings.ai_embeddings_enabled}}
      <AISuggestionDropdown
        @mode="suggest_category"
        @composer={{@outletArgs.composer}}
        class="suggest-category-button"
      />
    {{/if}}
  </template>
}
