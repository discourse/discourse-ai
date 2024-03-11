import { AUTO_GROUPS } from "discourse/lib/constants";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    const record = this.store.createRecord("ai-persona");
    record.set("allowed_group_ids", [AUTO_GROUPS.trust_level_0.id]);
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.show.discourse-ai.ai-personas")
    );
  },
});
