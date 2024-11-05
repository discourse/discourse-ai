import { withPluginApi } from "discourse/lib/plugin-api";

function initializeAiArtifactTabs(api) {
  api.decorateCooked(
    ($element) => {
      const element = $element[0];
      const artifacts = element.querySelectorAll(".ai-artifact");
      if (!artifacts.length) {
        return;
      }

      artifacts.forEach((artifact) => {
        const tabs = artifact.querySelectorAll(".ai-artifact-tab");
        const panels = artifact.querySelectorAll(".ai-artifact-panel");

        tabs.forEach((tab) => {
          tab.addEventListener("click", (e) => {
            e.preventDefault();

            if (tab.hasAttribute("data-selected")) {
              return;
            }

            const tabType = Object.keys(tab.dataset).find(
              (key) => key !== "selected"
            );

            tabs.forEach((t) => t.removeAttribute("data-selected"));
            panels.forEach((p) => p.removeAttribute("data-selected"));

            tab.setAttribute("data-selected", "");
            const targetPanel = artifact.querySelector(
              `.ai-artifact-panel[data-${tabType}]`
            );
            if (targetPanel) {
              targetPanel.setAttribute("data-selected", "");
            }
          });
        });
      });
    },
    {
      id: "ai-artifact-tabs",
      onlyStream: false,
    }
  );
}

export default {
  name: "ai-artifact-tabs",
  initialize() {
    withPluginApi("0.8.7", initializeAiArtifactTabs);
  },
};
