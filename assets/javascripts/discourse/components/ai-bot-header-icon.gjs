import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import { composeAiBotMessage } from "../lib/ai-bot-helper";

export default class AiBotHeaderIcon extends Component {
  @service currentUser;
  @service composer;

  get bots() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_persosna)
      .filter(Boolean);

    return availableBots ? availableBots.map((bot) => bot.model_name) : [];
  }

  @action
  compose() {
    composeAiBotMessage(this.bots[0], this.composer);
  }

  <template>
    {{#if (gt this.bots.length 0)}}
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
