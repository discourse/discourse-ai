import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeTopicSummary(api) {
  let summaryArea = null;

  api.modifyClass("component:scrolling-post-stream", {
    // TODO store state so we can toggle summary
    showAiSummary() {
      const topic_id = this.posts["posts"][0].topic_id;
      //TODO request summary and show it
    },
  });

  api.addTopicSummaryCallback((html, attrs, widget) => {
    html.push(
      // TODO copy and styling
      widget.attach("button", {
        className: "btn btn-primary",
        icon: "magic",
        title: "discourse_ai.ai_helper.title",
        label: "discourse_ai.ai_helper.title",
        action: "showAiSummary",
      })
    );

    return html;
  });
}

export default {
  name: "discourse_ai-topic_summary",

  initialize(container) {
    const settings = container.lookup("site-settings:main");
    const user = container.lookup("service:current-user");

    const summarizationEnabled =
      settings.discourse_ai_enabled && settings.ai_summarization_enabled;

    if (summarizationEnabled) {
      // Needs to be 1.7.0 for addTopicSummaryCallback
      withPluginApi("1.7.0", initializeTopicSummary);
    }
  },
};
