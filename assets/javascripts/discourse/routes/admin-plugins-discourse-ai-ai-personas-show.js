import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model(params) {
    const allPersonas = this.modelFor("adminPlugins.discourse-ai.ai-personas");
    const id = parseInt(params.id, 10);
    return allPersonas.findBy("id", id);
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allPersonas",
      this.modelFor("adminPlugins.discourse-ai.ai-personas")
    );
  },
});
