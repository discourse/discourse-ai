import Component from "@glimmer/component";
import { service } from "@ember/service";
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiTagSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAiHelper(
      outletArgs?.composer,
      helper.siteSettings,
      helper.currentUser,
      "suggestions"
    );
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
