import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Service, { service } from "@ember/service";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class AiBotConversationsHiddenSubmit extends Service {
  @service composer;
  @service dialog;

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
      // TODO: Translate
      this.dialog.alert({
        message: "Message must be longer than 10 characters",
        didConfirm: () => this.focusInput(),
        didCancel: () => this.focusInput(),
      });
    }

    // this is a total hack, the composer is hidden on the homepage with CSS
    await this.composer.open({
      action: Composer.PRIVATE_MESSAGE,
      draftKey: "private_message_ai",
      recipients: this.currentUser.ai_enabled_personas[0].username,
      topicTitle: i18n("discourse_ai.ai_bot.default_pm_prefix"),
      topicBody: this.inputValue,
      archetypeId: "private_message",
      disableDrafts: true,
    });

    try {
      await this.composer.save();
      if (this.inputValue.length > 10) {
        // prevents submitting same message again when returning home
        // but avoids deleting too-short message on submit
        this.inputValue = "";
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to submit message:", error);
    }
  }
}
