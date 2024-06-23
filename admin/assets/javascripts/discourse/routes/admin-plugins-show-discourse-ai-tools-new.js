import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    const record = this.store.createRecord("ai-tool");
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allTools",
      this.modelFor("adminPlugins.show.discourse-ai-tools")
    );
  },
});
