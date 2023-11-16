import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    return this.store.createRecord("ai-persona");
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.discourse-ai.ai-personas")
    );
  },
});
