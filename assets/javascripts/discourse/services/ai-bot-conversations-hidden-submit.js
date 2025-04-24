import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { tracked } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiBotConversationsHiddenSubmit extends Service {
  @service aiConversationsSidebarManager;
  @service appEvents;
  @service composer;
  @service dialog;
  @service router;

  @tracked loading = false;

  personaId;
  targetUsername;

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
    if (this.inputValue.length < 10) {
      return this.dialog.alert({
        message: i18n(
          "discourse_ai.ai_bot.conversations.min_input_length_message"
        ),
        didConfirm: () => this.focusInput(),
        didCancel: () => this.focusInput(),
      });
    }

    this.loading = true;
    const title = i18n("discourse_ai.ai_bot.default_pm_prefix");

    try {
      const response = await ajax("/posts.json", {
        method: "POST",
        data: {
          raw: this.inputValue,
          title,
          archetype: "private_message",
          target_recipients: this.targetUsername,
          meta_data: { ai_persona_id: this.personaId },
        },
      });

      this.appEvents.trigger("discourse-ai:bot-pm-created", {
        id: response.topic_id,
        slug: response.topic_slug,
        title,
      });
      this.router.transitionTo(response.post_url);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }
}
