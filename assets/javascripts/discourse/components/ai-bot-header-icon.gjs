import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";
import { composeAiBotMessage } from "../lib/ai-bot-helper";
import AiBotHeaderPanel from "./ai-bot-header-panel";

export default class AiBotHeaderIcon extends Component {
  @service siteSettings;
  @service composer;

  get bots() {
    return this.siteSettings.ai_bot_add_to_header
      ? this.siteSettings.ai_bot_enabled_chat_bots.split("|").filter(Boolean)
      : [];
  }

  @action
  compose() {
    composeAiBotMessage(this.bots[0], this.composer);
  }

  <template>
    {{#if (gt this.bots.length 0)}}
      <li>
        {{#if (gt this.bots.length 1)}}
          <DMenu
            @icon="robot"
            @title={{i18n "discourse_ai.ai_bot.shortcut_title"}}
            class="ai-bot-button icon btn-flat"
          >
            <:content as |args|>
              <AiBotHeaderPanel @closePanel={{args.close}} />
            </:content>
          </DMenu>
        {{else}}
          <DButton
            @icon="robot"
            @title={{i18n "discourse_ai.ai_bot.shortcut_title"}}
            class="ai-bot-button icon btn-flat"
            @action={{this.compose}}
          />
        {{/if}}
      </li>
    {{/if}}
  </template>
}
