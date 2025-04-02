import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiFeatures extends DiscourseRoute {
  async model() {
    const { ai_features } = await ajax(
      `/admin/plugins/discourse-ai/ai-features.json`
    );
    return ai_features;
  }
}
