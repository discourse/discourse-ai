import { withPluginApi } from "discourse/lib/plugin-api";
import AdminReportEmotion from "discourse/plugins/discourse-ai/discourse/components/admin-report-emotion";

export default {
  name: "discourse-ai-admin-reports",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser || !currentUser.admin) {
      return;
    }

    withPluginApi("2.0.1", (api) => {
      api.registerReportModeComponent("emotion", AdminReportEmotion);
    });
  },
};
