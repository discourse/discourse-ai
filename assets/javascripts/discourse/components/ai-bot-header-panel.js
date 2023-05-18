import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import Component from "@ember/component";
import { ComposeAiBotMessage } from "discourse/plugins/discourse-ai/discourse/lib/ai-bot-helper";

import I18n from "I18n";

export default class AiBotHeaderPanel extends Component {
  @service siteSettings;
  @service composer;
  @service appEvents;

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

  get botNames() {
    return this.enabledBotOptions.map((bot) => {
      return {
        humanized: I18n.t(`discourse_ai.ai_bot.bot_names.${bot}`),
        modelName: bot,
      };
    });
  }

  get enabledBotOptions() {
    return this.siteSettings.ai_bot_enabled_chat_bots.split("|");
  }

  get singleBotEnabled() {
    return this.enabledBotOptions.length === 1;
  }

  async _composeAiBotMessage(targetBot) {
    ComposeAiBotMessage(targetBot, this.composer, this.appEvents);
  }
}
