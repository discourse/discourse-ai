import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const TRANSLATE = "translate";
const GENERATE_TITLES = "generate_titles";
const PROOFREAD = "proofread";

export default class AiHelper extends Component {
  @tracked selected = null;
  @tracked loading = false;

  @tracked generatedTitlesSuggestions = [];

  @tracked proofReadSuggestion = null;
  @tracked translatedSuggestion = null;
  @tracked selectedTitle = null;

  @tracked proofreadDiff = null;

  helperOptions = [
    {
      name: I18n.t("discourse_ai.ai_helper.modes.translate"),
      value: TRANSLATE,
    },
    {
      name: I18n.t("discourse_ai.ai_helper.modes.generate_titles"),
      value: GENERATE_TITLES,
    },
    {
      name: I18n.t("discourse_ai.ai_helper.modes.proofreader"),
      value: PROOFREAD,
    },
  ];

  get composedMessage() {
    const editor = this.args.editor;

    return editor.getSelected().value || editor.value;
  }

  @computed("selected", "selectedTitle", "translatingText", "proofreadingText")
  get canSave() {
    return (
      (this.selected === GENERATE_TITLES && this.selectedTitle) ||
      this.translatingText ||
      this.proofreadingText
    );
  }

  @computed("selected", "translatedSuggestion")
  get translatingText() {
    return this.selected === TRANSLATE && this.translatedSuggestion;
  }

  @computed("selected", "proofReadSuggestion")
  get proofreadingText() {
    return this.selected === PROOFREAD && this.proofReadSuggestion;
  }

  @computed("selected", "generatedTitlesSuggestions")
  get selectingTopicTitle() {
    return (
      this.selected === GENERATE_TITLES &&
      this.generatedTitlesSuggestions.length > 0
    );
  }

  _updateSuggestedByAI(value, data) {
    switch (value) {
      case GENERATE_TITLES:
        this.generatedTitlesSuggestions = data.suggestions;
        break;
      case TRANSLATE:
        this.translatedSuggestion = data.suggestions[0];
        break;
      case PROOFREAD:
        this.proofReadSuggestion = data.suggestions[0];
        this.proofreadDiff = data.diff;
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

    if (this.hasSuggestion) {
      this.loading = false;
    } else {
      return ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: { mode: this.selected, text: this.composedMessage },
      })
        .then((data) => {
          this._updateSuggestedByAI(value, data);
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    }
  }

  @action
  applySuggestion() {
    if (this.selectingTopicTitle) {
      const composer = this.args.editor.parentView.composer;
      composer.set("title", this.selectedTitle);
    } else {
      const newText = this.proofreadingText
        ? this.proofReadSuggestion
        : this.translatedSuggestion;
      this.args.editor.replaceText(this.composedMessage, newText);
    }

    this.args.closeModal();
  }
}
