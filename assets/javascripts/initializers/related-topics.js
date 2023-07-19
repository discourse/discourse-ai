import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-ai-related-topics",

  initialize(container) {
    const settings = container.lookup("service:site-settings");

    if (settings.ai_embeddings_semantic_related_topics_enabled) {
      withPluginApi("1.1.0", (api) => {
        api.modifyClass("model:post-stream", {
          pluginId: "discourse-ai",

          _setSuggestedTopics(result) {
            this._super(...arguments);

            if (!result.related_topics) {
              return;
            }

            this.topic.setProperties({
              related_topics: result.related_topics,
            });
          },
        });
      });
    }
  },
};
