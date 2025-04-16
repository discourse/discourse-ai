import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiBotConversationsRoute extends DiscourseRoute {
  @service aiConversationsSidebarManager;

  activate() {
    super.activate(...arguments);
    this.aiConversationsSidebarManager.forceCustomSidebar();
  }

  deactivate() {
    super.deactivate(...arguments);
    this.aiConversationsSidebarManager.stopForcingCustomSidebar();
  }
}
