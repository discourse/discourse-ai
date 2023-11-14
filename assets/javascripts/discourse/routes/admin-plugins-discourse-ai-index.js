import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel() {
    this.transitionTo("adminPlugins.discourse-ai.ai-personas");
  },
});
