import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import { composeAiBotMessage } from "../lib/ai-bot-helper";

export default class AiBotHeaderIcon extends Component {
  @service currentUser;
  @service siteSettings;
  @service composer;
  @service router;

  get bots() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_persosna)
      .filter(Boolean);

    return availableBots ? availableBots.map((bot) => bot.model_name) : [];
  }

  get showHeaderButton() {
    return this.bots.length > 0 && this.siteSettings.ai_bot_add_to_header;
  }

  @action
  compose() {
    if (this.siteSettings.ai_enable_experimental_bot_ux) {
      return this.router.transitionTo("discourse-ai-bot-conversations");
    }
    composeAiBotMessage(this.bots[0], this.composer);
  }

  <template>
    {{#if this.showHeaderButton}}
      <li>
        <DButton
          @action={{this.compose}}
          @icon="robot"
          title={{i18n "discourse_ai.ai_bot.shortcut_title"}}
          class="ai-bot-button icon btn-flat"
        />
      </li>
    {{/if}}
  </template>
}
