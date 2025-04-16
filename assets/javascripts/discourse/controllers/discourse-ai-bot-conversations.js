import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;

  sidebarEnabled = true;
  showSidebar = true;
  textareaInteractor = null;

  @action
  updateInputValue(event) {
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
