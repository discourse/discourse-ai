import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { computed } from "@ember/object";

export default class extends Component {
  static shouldRender(args) {
    return (args.model.related_topics?.length || 0) > 0;
  }

  @service store;
  @service site;
  @service moreTopicsPreferenceTracking;

  listId = "related-topics";

  @computed("moreTopicsPreferenceTracking.preference")
  get hidden() {
    return this.moreTopicsPreferenceTracking.preference !== this.listId;
  }

  get relatedTopics() {
    return this.args.outletArgs.model.related_topics.map((topic) =>
      this.store.createRecord("topic", topic)
    );
  }
}
