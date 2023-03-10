import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeComposerAIHelper(api) {
  api.modifyClass("component:d-editor", {
    pluginId: "discourse-ai",

    actions: {
      openAIHelper() {
        if (this.value) {
          showModal("composer-ai-helper").setProperties({ editor: this });
        }
      },
    },
  });

  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "ai-helper",
      title: "discourse_ai.ai_helper.title",
      group: "extras",
      icon: "magic",
      className: "composer-ai-helper",
      sendAction: () => toolbar.context.send("openAIHelper"),
    });
  });
}

export default {
  name: "discourse_ai-composer-helper",

  initialize(container) {
    const settings = container.lookup("site-settings:main");
    const user = container.lookup("service:current-user");

    const helperEnabled =
      settings.discourse_ai_enabled && settings.composer_ai_helper_enabled;

    const allowedGroups = settings.ai_helper_allowed_groups
      .split("|")
      .map(parseInt);
    const canUseAssistant =
      user && user.groups.some((g) => allowedGroups.includes(g.id));

    if (helperEnabled && canUseAssistant) {
      withPluginApi("1.6.0", initializeComposerAIHelper);
    }
  },
};
