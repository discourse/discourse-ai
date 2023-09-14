import Component from '@glimmer/component';
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";
import showAIHelper from "../../lib/show-ai-helper";

export default class AITitleSuggestion extends Component {
  <template>
    <AISuggestionDropdown @mode="suggest_title" @composer={{@outletArgs.composer}} class="suggest-titles-button" />
  </template>

  static shouldRender(outletArgs, helper) {
    return showAIHelper(outletArgs, helper);
  }
}