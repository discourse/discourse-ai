import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@ember-compat/tracked-built-ins";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;
  @service currentUser;

  @tracked selectedPersona = this.personaOptions[0].username;

  textarea = null;

  init() {
    super.init(...arguments);
    this.selectedPersonaChanged(this.selectedPersona);
  }

  get personaOptions() {
    if (this.currentUser.ai_enabled_personas) {
      return this.currentUser.ai_enabled_personas
        .filter((persona) => persona.username)
        .map((persona) => {
          return {
            id: persona.id,
            username: persona.username,
            name: persona.name,
            description: persona.description,
          };
        });
    }
  }

  get filterable() {
    return this.personaOptions.length > 4;
  }

  @action
  selectedPersonaChanged(username) {
    this.selectedPersona = username;
    this.aiBotConversationsHiddenSubmit.personaUsername = username;
  }

  @action
  updateInputValue(event) {
    this._autoExpandTextarea();
    this.aiBotConversationsHiddenSubmit.inputValue = event.target.value;
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      this.aiBotConversationsHiddenSubmit.submitToBot();
    }
  }

  @action
  setTextArea(element) {
    this.textarea = element;
  }

  _autoExpandTextarea() {
    this.textarea.style.height = "auto";
    this.textarea.style.height = this.textarea.scrollHeight + "px";
  }
}
