import { withPluginApi } from "discourse/lib/plugin-api";
import ModalDiffModal from "../discourse/components/modal/diff-modal";

function initializeProofread(api) {
  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const modal = api.container.lookup("service:modal");

      modal.show(ModalDiffModal, {
        model: {
          selected: toolbarEvent.selected,
          toolbarEvent,
        },
      });
    },
    icon: "spell-check",
    label: "discourse_ai.ai_helper.context_menu.proofread_prompt",
    shortcut: "ALT+P",
    condition: () => {
      const siteSettings = api.container.lookup("service:site-settings");
      const currentUser = api.getCurrentUser();

      return (
        siteSettings.ai_helper_enabled && currentUser?.can_use_assistant_in_post
      );
    },
  });
}

export default {
  name: "discourse-ai-helper",

  initialize() {
    withPluginApi("1.1.0", (api) => {
      initializeProofread(api);
    });
  },
};
