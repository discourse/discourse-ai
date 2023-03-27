export default {
  shouldRender(args) {
    return (args.model.related_topics?.length || 0) > 0;
  },
  setupComponent(args, component) {
    if (component.model.related_topics) {
      component.set(
        "relatedTopics",
        component.model.related_topics.map((topic) =>
          this.store.createRecord("topic", topic)
        )
      );
    }
  },
};
