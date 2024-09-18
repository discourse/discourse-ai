import Component from "@glimmer/component";
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import { showComposerAiHelper } from "../../lib/show-ai-helper";

export default class AiTitleSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAiHelper(
      outletArgs?.composer,
      helper.siteSettings,
      helper.currentUser,
      "suggestions"
    );
  }

  <template>
    <AISuggestionDropdown
      @mode="suggest_title"
      @composer={{@outletArgs.composer}}
      class="suggest-titles-button"
    />
  </template>
}
