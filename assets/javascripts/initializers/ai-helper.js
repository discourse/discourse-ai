import { withPluginApi } from "discourse/lib/plugin-api";
import i18n from "discourse-common/helpers/i18n";
import ModalDiffModal from "../discourse/components/modal/diff-modal";

function initializeProofread(api) {
  api.addComposerToolbarPopupMenuOption({
    action: (toolbarEvent) => {
      const modal = api.container.lookup("service:modal");
      const composer = api.container.lookup("service:composer");
      const toasts = api.container.lookup("service:toasts");

      if (composer.model.reply?.length === 0) {
        toasts.error({
          duration: 3000,
          data: {
            message: i18n("discourse_ai.ai_helper.proofread.no_content_error"),
          },
        });
        return;
      }

      modal.show(ModalDiffModal, {
        model: {
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
