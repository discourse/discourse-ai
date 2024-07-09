import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsNewRoute extends DiscourseRoute {
  async model() {
    return this.store.createRecord("ai-tool");
  }

  setupController(controller) {
    super.setupController(...arguments);
    const toolsModel = this.modelFor("adminPlugins.show.discourse-ai-tools");

    controller.set("allTools", toolsModel);
    controller.set("presets", toolsModel.resultSetMeta.presets);
  }
}
