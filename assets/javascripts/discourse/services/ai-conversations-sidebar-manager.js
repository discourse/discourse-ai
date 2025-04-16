import { alias } from "@ember/object/computed";
import Service, { service } from "@ember/service";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";

export default class AiConversationsSidebarManager extends Service {
  @service sidebarState;

  @alias("sidebarState.isForcingSidebar") isForcingSidebar;

  forceCustomSidebar() {
    // Set the panel to your custom panel
    this.sidebarState.setPanel("ai-conversations");

    // Use separated mode to ensure independence from hamburger menu
    this.sidebarState.setSeparatedMode();

    // Hide panel switching buttons to keep UI clean
    this.sidebarState.hideSwitchPanelButtons();

    this.isForcingSidebar = true;
    return true;
  }

  stopForcingCustomSidebar() {
    // This method is called when leaving your route
    // Only restore main panel if we previously forced ours
    if (this.isForcingSidebar) {
      this.sidebarState.setPanel(MAIN_PANEL); // Return to main sidebar panel
      this.isForcingSidebar = false;
    }
  }
}
