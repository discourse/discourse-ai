import { apiInitializer } from "discourse/lib/api";
import { bind } from "discourse-common/utils/decorators";
import AiTopicSummary from "../discourse/lib/ai-topic-summary";

export default apiInitializer("1.25.0", (api) => {
  // api.modifyClass("model:post-stream", {
  //   pluginId: "discourse-ai",
  //   topicSummary: null,
  //   init() {
  //     this._super(...arguments);
  //     this.set("topicSummary", new AiTopicSummary());
  //   },
  //   collapseSummary() {
  //     this.topicSummary.collapse();
  //   },
  //   showSummary(currentUser) {
  //     this.topicSummary.generateSummary(currentUser, this.get("topic.id"));
  //   },
  //   processSummaryUpdate(update) {
  //     this.topicSummary.processUpdate(update);
  //   },
  // });
  // api.modifyClass("controller:topic", {
  //   pluginId: "discourse-ai",
  //   collapseSummary() {
  //     this.get("model.postStream").collapseSummary();
  //   },
  //   showSummary() {
  //     this.get("model.postStream").showSummary(this.currentUser);
  //   },
  // });
});
