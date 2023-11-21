import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    const record = this.store.createRecord("ai-persona");
    // TL0
    record.set("allowed_group_ids", [10]);
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.discourse-ai.ai-personas")
    );
  },
});
