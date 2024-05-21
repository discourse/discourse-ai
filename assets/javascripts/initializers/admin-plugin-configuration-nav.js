import { PLUGIN_NAV_MODE_TOP } from "discourse/lib/admin-plugin-config-nav";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-ai-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("discourse-ai", PLUGIN_NAV_MODE_TOP, [
        {
          label: "discourse_ai.ai_persona.short_title",
          route: "adminPlugins.show.discourse-ai-personas",
        },
        {
          label: "discourse_ai.llms.short_title",
          route: "adminPlugins.show.discourse-ai-llms",
        },
      ]);
    });
  },
};
