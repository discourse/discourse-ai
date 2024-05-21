import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model(params) {
    const allLlms = this.modelFor("adminPlugins.show.discourse-ai-llms");
    const id = parseInt(params.id, 10);
    return allLlms.findBy("id", id);
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allLlms",
      this.modelFor("adminPlugins.show.discourse-ai-llms")
    );
  },
});
