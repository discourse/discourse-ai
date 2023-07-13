import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class extends Component {
  static shouldRender(args) {
    return (args.model.related_topics?.length || 0) > 0;
  }

  @service store;

  get relatedTopics() {
    return this.args.outletArgs.model.related_topics.map((topic) =>
      this.store.createRecord("topic", topic)
    );
  }
}
