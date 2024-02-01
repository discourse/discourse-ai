import Component from "@glimmer/component";
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import { showComposerAIHelper } from "../../lib/show-ai-helper";

export default class AiTitleSuggestion extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAIHelper(outletArgs, helper, "suggestions");
  }

  <template>
    <AISuggestionDropdown
      @mode="suggest_title"
      @composer={{@outletArgs.composer}}
      class="suggest-titles-button"
    />
  </template>
}
