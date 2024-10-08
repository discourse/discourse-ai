import Component from "@glimmer/component";
import { service } from "@ember/service";
import BasicTopicList from "discourse/components/basic-topic-list";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";

const LIST_ID = "related-topics";

export default class extends Component {
  static shouldRender(args) {
    return args.model.related_topics?.length;
  }

  @service store;
  @service moreTopicsPreferenceTracking;

  constructor() {
    super(...arguments);
    this.moreTopicsPreferenceTracking.registerTopicList({
      name: i18n("discourse_ai.related_topics.pill"),
      id: LIST_ID,
      icon: "discourse-sparkles",
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.moreTopicsPreferenceTracking.removeTopicList(LIST_ID);
  }

  get hidden() {
    return this.moreTopicsPreferenceTracking.selectedTab !== LIST_ID;
  }

  get relatedTopics() {
    return this.args.outletArgs.model.related_topics.map((topic) =>
      this.store.createRecord("topic", topic)
    );
  }

  <template>
    <div
      role="complementary"
      aria-labelledby="related-topics-title"
      id="related-topics"
      class={{concatClass "more-topics__list" (if this.hidden "hidden")}}
    >
      <h3 id="related-topics-title" class="more-topics__list-title">
        {{i18n "discourse_ai.related_topics.title"}}
      </h3>

      <div class="topics">
        <BasicTopicList @topics={{this.relatedTopics}} />
      </div>
    </div>
  </template>
}
