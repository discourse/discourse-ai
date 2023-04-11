import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

function initializeTopicSummary(api) {
  api.modifyClass("component:scrolling-post-stream", {
    showAiSummary() {
      showModal("ai-summary").setProperties({
        targetId: this.posts["posts"][0].topic_id,
        targetType: "topic",
        allowTimeframe: false,
      });
    },
  });

  api.addTopicSummaryCallback((html, attrs, widget) => {
    html.push(
      widget.attach("button", {
        className: "btn btn-primary topic-ai-summarization",
        icon: "magic",
        title: "discourse_ai.summarization.title",
        label: "discourse_ai.summarization.title",
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

    const summarizationEnabled =
      settings.discourse_ai_enabled && settings.ai_summarization_enabled;

    if (summarizationEnabled) {
      withPluginApi("1.6.0", initializeTopicSummary);
    }
  },
};
