import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { composeAiBotMessage } from "discourse/plugins/discourse-ai/discourse/lib/ai-bot-helper";

export default class AiBotHeaderPanel extends Component {
  @service siteSettings;
  @service composer;

  @action
  composeMessageWithTargetBot(target) {
    this.#composeAiBotMessage(target);
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

  #composeAiBotMessage(targetBot) {
    this.args.closePanel();
    composeAiBotMessage(targetBot, this.composer);
  }
}
