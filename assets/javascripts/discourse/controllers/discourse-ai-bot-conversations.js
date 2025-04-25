import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;
  @service currentUser;

  textarea = null;

  init() {
    super.init(...arguments);
  }

  get loading() {
    return this.aiBotConversationsHiddenSubmit?.loading;
  }

  @action
  setPersonaId(id) {
    this.aiBotConversationsHiddenSubmit.personaId = id;
  }

  @action
  setTargetRecipient(username) {
    this.aiBotConversationsHiddenSubmit.targetUsername = username;
  }

  @action
  updateInputValue(value) {
    this._autoExpandTextarea();
    this.aiBotConversationsHiddenSubmit.inputValue =
      value.target?.value || value;
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

    // Get the max-height value from CSS (30vh)
    const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10);

    // Only enable scrolling if content exceeds max-height
    if (this.textarea.scrollHeight > maxHeight) {
      this.textarea.style.overflowY = "auto";
    } else {
      this.textarea.style.overflowY = "hidden";
    }
  }
}
