import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model(params) {
    const allTools = this.modelFor("adminPlugins.show.discourse-ai-tools");
    const id = parseInt(params.id, 10);
    return allTools.findBy("id", id);
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allTools",
      this.modelFor("adminPlugins.show.discourse-ai-tools")
    );
  },
});
