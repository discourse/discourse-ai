import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class AiBotSidebarNewConversation extends Component {
  @service router;

  get show() {
    return this.router.currentRouteName !== "discourse-ai-bot-conversations";
  }

  <template>
    {{#if this.show}}
      <DButton
        @route="/discourse-ai/ai-bot/conversations"
        @translatedLabel="TODO: new_question"
        @icon="plus"
        class="ai-new-question-button btn-default"
      />
    {{/if}}
  </template>
}
