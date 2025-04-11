import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class AiBotSidebarNewConversation extends Component {
  @service router;

  get show() {
    // don't show the new question button on the conversations home page
    return this.router.currentRouteName !== "discourse-ai-bot-conversations";
  }

  <template>
    {{#if this.show}}
      <DButton
        @route="/discourse-ai/ai-bot/conversations"
        @label="discourse_ai.ai_bot.conversations.new"
        @icon="plus"
        class="ai-new-question-button btn-default"
      />
    {{/if}}
  </template>
}
