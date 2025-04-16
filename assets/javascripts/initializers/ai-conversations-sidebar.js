// discourse/initializers/your-custom-sidebar.js
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi("1.8.0", (api) => {
      // Step 1: Add a custom sidebar panel
      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AiConversationsSidebarPanel extends BaseCustomSidebarPanel {
            key = "ai-conversations";
            hidden = true; // Hide from panel switching UI
            displayHeader = true;
            expandActiveSection = true;

            // Optional - customize if needed
            // switchButtonLabel = "Your Panel";
            // switchButtonIcon = "cog";
          }
      );

      // Step 2: Add a custom section to your panel
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class AiConversationsSidebarSection extends BaseCustomSidebarSection {
            name = "your-custom-section";
            text = "Your Section Title";

            get links() {
              return [
                // Add your links here
                //new (class extends BaseCustomSidebarSectionLink {
                //name = "custom-link-1";
                //route = "some.route";
                //text = "First Custom Link";
                //prefixType = "icon";
                //prefixValue = "cog";
                //})(),
                //new (class extends BaseCustomSidebarSectionLink {
                //name = "custom-link-2";
                //route = "another.route";
                //text = "Second Custom Link";
                //prefixType = "icon";
                //prefixValue = "bell";
                //})()
              ];
            }
          };
        },
        "ai-conversations" // Important: Attach to your panel
      );
    });
  },
};
