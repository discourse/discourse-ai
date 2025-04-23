import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;
  @service currentUser;

  @alias("aiBotConversationsHiddenSubmit.loading") loading;

  textarea = null;

  init() {
    super.init(...arguments);
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
