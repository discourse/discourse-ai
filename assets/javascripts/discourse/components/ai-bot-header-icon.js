import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Component from "@ember/component";
import Composer from "discourse/models/composer";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";

export default class AiBotHeaderIcon extends Component {
  @service siteSettings;
  @service composer;

  @tracked open = false;

  @action
  async toggleBotOptions() {
    this.open = !this.open;
  }

  @action
  async composeMessageWithTargetBot(target) {
    this._composeAiBotMessage(target);
  }

  @action
  async singleComposeAiBotMessage() {
    this._composeAiBotMessage(
      this.siteSettings.ai_bot_enabled_chat_bots.split("|")[0]
    );
  }

  @action
  registerClickListener() {
    this.#addClickEventListener();
  }

  @action
  unregisterClickListener() {
    this.#removeClickEventListener();
  }

  @bind
  closeDetails(event) {
    if (this.open) {
      const isLinkClick = event.target.className.includes(
        "ai-bot-toggle-available-bots"
      );

      if (isLinkClick || this.#isOutsideDetailsClick(event)) {
        this.open = false;
      }
    }
  }

  #isOutsideDetailsClick(event) {
    return !event.composedPath().some((element) => {
      return element.className === "ai-bot-available-bot-options";
    });
  }

  #removeClickEventListener() {
    document.removeEventListener("click", this.closeDetails);
  }

  #addClickEventListener() {
    document.addEventListener("click", this.closeDetails);
  }

  get enabledBotOptions() {
    return this.siteSettings.ai_bot_enabled_chat_bots.split("|");
  }

  get singleBotEnabled() {
    return this.enabledBotOptions.length === 1;
  }

  async _composeAiBotMessage(targetBot) {
    let botUsername = await ajax("/discourse-ai/ai-bot/bot-username", {
      data: { username: targetBot },
    }).then((data) => {
      return data.bot_username;
    });

    this.composer.open({
      action: Composer.PRIVATE_MESSAGE,
      recipients: botUsername,
      topicTitle: `${I18n.t(
        "discourse_ai.ai_bot.default_pm_prefix"
      )} ${botUsername}`,
      archetypeId: "private_message",
      draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
      hasGroups: false,
    });

    this.open = false;
  }
}
