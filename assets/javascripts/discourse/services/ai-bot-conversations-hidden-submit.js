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
      return this.dialog.alert({
        message: i18n(
          "discourse_ai.ai_bot.conversations.min_input_length_message"
        ),
        didConfirm: () => this.focusInput(),
        didCancel: () => this.focusInput(),
      });
    }

    // borrowed from ai-bot-helper.js
    const draftKey = "new_private_message_ai_" + new Date().getTime();

    // For now.. find a persona with a username..
    const selectedPersona = this.currentUser.ai_enabled_personas.find(
      (persona) => persona.username
    );

    // this is a total hack, the composer is hidden on the homepage with CSS
    await this.composer.open({
      action: Composer.PRIVATE_MESSAGE,
      draftKey,
      recipients: selectedPersona.username,
      topicTitle: i18n("discourse_ai.ai_bot.default_pm_prefix"),
      topicBody: this.inputValue,
      archetypeId: "private_message",
      disableDrafts: true,
    });

    this.composer.model.metaData = { ai_persona_id: selectedPersona.id };

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
