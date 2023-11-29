import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service("router"),
  beforeModel() {
    this.router.transitionTo("adminPlugins.discourse-ai.ai-personas");
  },
});
