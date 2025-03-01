import Controller from "@ember/controller";
import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";
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
