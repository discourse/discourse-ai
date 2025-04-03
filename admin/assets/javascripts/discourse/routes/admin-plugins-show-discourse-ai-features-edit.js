import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDiscourseAiFeaturesEdit extends DiscourseRoute {
  async model(params) {
    const allFeatures = this.modelFor(
      "adminPlugins.show.discourse-ai-features"
    );
    const id = parseInt(params.id, 10);

    return allFeatures.find((feature) => feature.id === id);
  }
}
