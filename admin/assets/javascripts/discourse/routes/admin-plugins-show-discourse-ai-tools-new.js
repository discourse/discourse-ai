import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    const record = this.store.createRecord("ai-tool");
    return record;
  },

  setupController(controller, model) {
    this._super(controller, model);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");

    controller.set("allTools", toolsModel);
    controller.set("presets", toolsModel.resultSetMeta.presets);
  },
});
