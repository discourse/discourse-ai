import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiToolsRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("ai-tool");
  }
}
