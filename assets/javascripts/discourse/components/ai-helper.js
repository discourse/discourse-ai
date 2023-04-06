import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const LIST = "list";
const TEXT = "text";
const DIFF = "diff";

export default class AiHelper extends Component {
  @tracked selected = null;
  @tracked loading = false;

  @tracked generatedTitlesSuggestions = [];

  @tracked proofReadSuggestion = null;
  @tracked translatedSuggestion = null;
  @tracked selectedTitle = null;

  @tracked proofreadDiff = null;

  @tracked helperOptions = [];
  prompts = [];
  promptTypes = {};

  constructor() {
    super(...arguments);
    this.loadPrompts();
  }

  async loadPrompts() {
    let prompts = await ajax("/discourse-ai/ai-helper/prompts");

    prompts.map((p) => {
      this.prompts[p.id] = p;
    });

    this.promptTypes = prompts.reduce((memo, p) => {
      memo[p.name] = p.prompt_type;
      return memo;
    }, {});

    this.helperOptions = prompts.map((p) => {
      return {
        name: p.translated_name,
        value: p.id,
      };
    });
  }

  get composedMessage() {
    const editor = this.args.editor;

    return editor.getSelected().value || editor.value;
  }

  @computed("selected", "selectedTitle", "translatingText", "proofreadingText")
  get canSave() {
    return (
      (this.selected &&
        this.prompts[this.selected].prompt_type === LIST &&
        this.selectedTitle) ||
      this.translatingText ||
      this.proofreadingText
    );
  }

  @computed("selected", "translatedSuggestion")
  get translatingText() {
    return (
      this.selected &&
      this.prompts[this.selected].prompt_type === TEXT &&
      this.translatedSuggestion
    );
  }

  @computed("selected", "proofReadSuggestion")
  get proofreadingText() {
    return (
      this.selected &&
      this.prompts[this.selected].prompt_type === DIFF &&
      this.proofReadSuggestion
    );
  }

  @computed("selected", "generatedTitlesSuggestions")
  get selectingTopicTitle() {
    return (
      this.selected &&
      this.prompts[this.selected].prompt_type === LIST &&
      this.generatedTitlesSuggestions.length > 0
    );
  }

  _updateSuggestedByAI(data) {
    switch (data.type) {
      case LIST:
        this.generatedTitlesSuggestions = data.suggestions;
        break;
      case TEXT:
        this.translatedSuggestion = data.suggestions[0];
        break;
      case DIFF:
        this.proofReadSuggestion = data.suggestions[0];
        this.proofreadDiff = data.diff;
        break;
    }
  }

  @action
  async updateSelected(value) {
    this.loading = true;
    this.selected = value;

    if (value === LIST) {
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
          this._updateSuggestedByAI(data);
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    }
  }

  @action
  applySuggestion() {
    if (this.selectingTopicTitle) {
      const composer = this.args.editor.outletArgs?.composer;

      if (composer) {
        composer.set("title", this.selectedTitle);
      }
    } else {
      const newText = this.proofreadingText
        ? this.proofReadSuggestion
        : this.translatedSuggestion;
      this.args.editor.replaceText(this.composedMessage, newText);
    }

    this.args.closeModal();
  }
}
