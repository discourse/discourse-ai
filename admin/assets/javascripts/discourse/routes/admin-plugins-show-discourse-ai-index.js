import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    return this.router.transitionTo(
      "adminPlugins.show.discourse-ai.ai-personas.index"
    );
  }
}
