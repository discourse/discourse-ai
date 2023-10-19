import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action, computed } from "@ember/object";
import I18n from "I18n";

export default class extends Component {
  static shouldRender(args) {
    return (args.model.related_topics?.length || 0) > 0;
  }

  @service store;
  @service site;
  @service moreTopicsPreferenceTracking;

  listId = "related-topics";

  @computed("moreTopicsPreferenceTracking.selectedTab")
  get hidden() {
    return this.moreTopicsPreferenceTracking.selectedTab !== this.listId;
  }

  get relatedTopics() {
    return this.args.outletArgs.model.related_topics.map((topic) =>
      this.store.createRecord("topic", topic)
    );
  }

  @action
  registerList() {
    this.moreTopicsPreferenceTracking.registerTopicList({
      name: I18n.t("discourse_ai.related_topics.pill"),
      id: this.listId,
      icon: "discourse-sparkles",
    });
  }

  @action
  removeList() {
    this.moreTopicsPreferenceTracking.removeTopicList(this.listId);
  }
}
