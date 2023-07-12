import Component from "@glimmer/component";

export default class extends Component {
  static shouldRender(args) {
    return (args.model.related_topics?.length || 0) > 0;
  }

  get relatedTopics() {
    return this.args.model.related_topics.map((topic) =>
      this.store.createRecord("topic", topic)
    );
  }
}
