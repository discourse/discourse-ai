import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  queryParams: {
    llmTemplate: { refreshModel: true },
  },

  async model() {
    const record = this.store.createRecord("ai-llm");
    record.provider_params = {};
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    controller.set(
      "allLlms",
      this.modelFor("adminPlugins.show.discourse-ai-llms")
    );
    controller.set(
      "llmTemplate",
      this.paramsFor(this.routeName).llmTemplate || null
    );
  },
});
