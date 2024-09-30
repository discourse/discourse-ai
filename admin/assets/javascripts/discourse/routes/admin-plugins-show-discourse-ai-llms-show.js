import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model(params) {
    const allLlms = this.modelFor("adminPlugins.show.discourse-ai-llms");
    const id = parseInt(params.id, 10);
    const record = allLlms.findBy("id", id);
    record.provider_params = record.provider_params || {};
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allLlms",
      this.modelFor("adminPlugins.show.discourse-ai-llms")
    );
  },
});
