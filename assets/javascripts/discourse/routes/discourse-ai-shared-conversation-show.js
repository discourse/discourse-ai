import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel(transition) {
    window.location = transition.intent.url;
    transition.abort();
  },
});
