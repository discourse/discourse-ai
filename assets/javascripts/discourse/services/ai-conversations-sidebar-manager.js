import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";

export const AI_CONVERSATIONS_PANEL = "ai-conversations";

export default class AiConversationsSidebarManager extends Service {
  @service appEvents;
  @service sidebarState;

  @tracked newTopicForceSidebar = false;

  forceCustomSidebar() {
    // Return early if we already have the correct panel, so we don't
    // re-render it.
    if (this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL) {
      return;
    }

    this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);

    // Use separated mode to ensure independence from hamburger menu
    this.sidebarState.setSeparatedMode();

    // Hide panel switching buttons to keep UI clean
    this.sidebarState.hideSwitchPanelButtons();

    this.sidebarState.isForcingSidebar = true;
    document.body.classList.add("has-ai-conversations-sidebar");
    return true;
  }

  stopForcingCustomSidebar() {
    // This method is called when leaving your route
    // Only restore main panel if we previously forced ours
    document.body.classList.remove("has-ai-conversations-sidebar");
    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;
    // only restore main panel if we previously forced our sidebar
    // and not if we are in admin sidebar
    if (this.sidebarState.isForcingSidebar && !isAdminSidebarActive) {
      this.sidebarState.setPanel(MAIN_PANEL); // Return to main sidebar panel
      this.sidebarState.isForcingSidebar = false;
    }

    this.appEvents.trigger("discourse-ai:stop-forcing-custom-sidebar");
  }
}
