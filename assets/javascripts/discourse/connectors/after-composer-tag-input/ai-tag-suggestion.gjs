import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import { showComposerAIHelper } from "../../lib/show-ai-helper";

export default class AITagSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAIHelper(outletArgs, helper);
  }

  @service siteSettings;

  <template>
    {{#if this.siteSettings.ai_embeddings_enabled}}
      <AISuggestionDropdown
        @mode="suggest_tags"
        @composer={{@outletArgs.composer}}
        class="suggest-tags-button"
      />
    {{/if}}
  </template>
}
