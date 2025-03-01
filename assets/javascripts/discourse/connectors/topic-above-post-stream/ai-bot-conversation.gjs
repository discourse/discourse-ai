import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";

export default class AiBotConversation extends Component {
  @service siteSettings;

  get show() {
    return (
      this.siteSettings.ai_enable_experimental_bot_ux &&
      this.args.outletArgs.model?.pm_with_non_human_user
    );
  }

  <template>
    {{#if this.show}}
      {{bodyClass "discourse-ai-bot-conversations-page"}}
    {{/if}}
  </template>
}
