import Component from "@glimmer/component";
import { action } from "@ember/object";
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

  @action
  routeTo() {
    this.router.transitionTo("/discourse-ai/ai-bot/conversations");
    this.args.outletArgs?.toggleNavigationMenu?.();
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        @label="discourse_ai.ai_bot.conversations.new"
        @icon="plus"
        @action={{this.routeTo}}
        class="ai-new-question-button btn-default"
      />
    {{/if}}
  </template>
}
