import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-ai-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("1.1.0", (api) => {
      api.addAdminPluginConfigurationNav("discourse-ai", "top", [
        {
          label: "admin.plugins.change_settings_short",
          route: "adminPlugins.show.settings",
        },
        {
          label: "discourse_ai.ai_persona.short_title",
          route: "adminPlugins.show.discourse-ai.ai-personas",
        },
      ]);
    });
  },
};
