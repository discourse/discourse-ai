import Component from '@glimmer/component';
import AISuggestionDropdown from "../../components/ai-suggestion-dropdown";

export default class AITitleSuggestion extends Component {
  <template>
    <AISuggestionDropdown @mode="suggest_title" @composer={{@outletArgs.composer}} class="suggest-titles-button" />
  </template>
}