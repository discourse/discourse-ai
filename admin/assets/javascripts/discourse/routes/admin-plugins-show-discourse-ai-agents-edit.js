import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiAgentsEdit extends DiscourseRoute {
  async model(params) {
    const allAgents = this.modelFor(
      "adminPlugins.show.discourse-ai-agents"
    );
    const id = parseInt(params.id, 10);
    return allAgents.findBy("id", id);
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set(
      "allAgents",
      this.modelFor("adminPlugins.show.discourse-ai-agents")
    );
  }
}
