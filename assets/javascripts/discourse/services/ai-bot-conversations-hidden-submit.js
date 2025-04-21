import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { composeAiBotMessage } from "../lib/ai-bot-helper";

export default class AiBotConversationsHiddenSubmit extends Service {
  @service composer;
  @service aiConversationsSidebarManager;
  @service dialog;

  personaUsername;

  inputValue = "";

  @action
  focusInput() {
    this.composer.destroyDraft();
    this.composer.close();
    next(() => {
      document.getElementById("custom-homepage-input").focus();
    });
  }

  @action
  async submitToBot() {
    this.composer.destroyDraft();
    this.composer.close();

    if (this.inputValue.length < 10) {
      return this.dialog.alert({
        message: i18n(
          "discourse_ai.ai_bot.conversations.min_input_length_message"
        ),
        didConfirm: () => this.focusInput(),
        didCancel: () => this.focusInput(),
      });
    }

    // we are intentionally passing null as the targetBot to allow for the
    // function to select the first available bot. This will be refactored in the
    // future to allow for selecting a specific bot.
    await composeAiBotMessage(null, this.composer, {
      skipFocus: true,
      topicBody: this.inputValue,
      personaUsername: this.personaUsername,
    });

    try {
      await this.composer.save();
      this.aiConversationsSidebarManager.newTopicForceSidebar = true;
      if (this.inputValue.length > 10) {
        // prevents submitting same message again when returning home
        // but avoids deleting too-short message on submit
        this.inputValue = "";
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
