import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { AI_CONVERSATIONS_PANEL } from "../services/ai-conversations-sidebar-manager";

export default class AiBotSidebarNewConversation extends Component {
  @service router;
  @service sidebarState;

  get shouldRender() {
    return (
      this.router.currentRouteName !== "discourse-ai-bot-conversations" &&
      this.sidebarState.isCurrentPanel(AI_CONVERSATIONS_PANEL)
    );
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        @route="/discourse-ai/ai-bot/conversations"
        @label="discourse_ai.ai_bot.conversations.new"
        @icon="plus"
        class="ai-new-question-button btn-default"
      />
    {{/if}}
  </template>
}
