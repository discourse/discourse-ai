import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import I18n from "I18n";

const TRANSLATE = "translate";
const GENERATE_TITLES = "generate_titles";
const PROOFREAD = "proofread";

export default class AIHelper extends Component {
  @tracked selected = null;
  @tracked loading = false;

  @tracked generatedTitlesSuggestions = [];
  
  @tracked proofReadSuggestion = null;
  @tracked translatedSuggestion = null;
  @tracked selectedTitle = null;

  helperOptions = [
    { name: I18n.t("discourse_ai.ai_helper.modes.translate"), value: TRANSLATE },
    { name: I18n.t("discourse_ai.ai_helper.modes.generate_titles"), value: GENERATE_TITLES },
    { name: I18n.t("discourse_ai.ai_helper.modes.proofreader"), value: PROOFREAD },
  ];

  get composedMessage() {
    const editor = this.args.editor;
    
    if (this.selectingTopicTitle) {
      return editor.parentView.composer.title;
    } else {
      return editor.getSelected().value || editor.value;  
    }
  }

  @computed("selected", "translatedSuggestion", "selectedTitle", "proofReadSuggestion")
  get canSave() {
    return (this.selected === GENERATE_TITLES && this.selectedTitle) || this.suggestingText;
  }

  @computed("selected", "translatedSuggestion", "proofReadSuggestion")
  get suggestingText() {
    return (
      (this.selected === TRANSLATE && this.translatedSuggestion) ||
      (this.selected === PROOFREAD && this.proofReadSuggestion)
    );
  }

  @computed("selected", "generatedTitlesSuggestions")
  get selectingTopicTitle() {
    return this.selected === GENERATE_TITLES && this.generatedTitlesSuggestions.length > 0;
  }

  @computed("selected", "translatedSuggestion", "proofReadSuggestion")
  get suggestedText() {
    if (this.selected === TRANSLATE) {
      return this.translatedSuggestion;
    } else {
      return this.proofReadSuggestion;
    }
  }

  _updateSuggestedByAI(value, suggestion) {
    switch(value) {
      case TRANSLATE:
        this.translatedSuggestion = suggestion;
        break;
      case GENERATE_TITLES:
        this.generatedTitlesSuggestions = [suggestion];
        break;
      case PROOFREAD:
        this.proofReadSuggestion = suggestion;
        break;
    }
  }
  
  @action
  async updateSelected(value) {
    this.loading = true;
    this.selected = value;

    if (value === GENERATE_TITLES) {
      this.selectedTitle = null;
    }

    if (!this.hasSuggestion) {
      const sleep = ms => new Promise(r => setTimeout(r, ms));
      await sleep(2000);
      this._updateSuggestedByAI(value, `(replaced with ${value} mode)`);
    }

    this.loading = false;
  }

  @action
  applySuggestion() {
    if (this.suggestingText) {
      this.args.editor.replaceText(this.composedMessage, this.suggestedText);
    } else {
      const composer = this.args.editor.parentView.composer;
      composer.set("title", this.selectedTitle);
    }

    this.args.closeModal();
  }
}