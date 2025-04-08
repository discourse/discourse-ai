import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SimpleTextareaInteractor from "../lib/simple-textarea-interactor";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;

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
  initializeTextarea(element) {
    this.textareaInteractor = new SimpleTextareaInteractor(element);
  }
}
