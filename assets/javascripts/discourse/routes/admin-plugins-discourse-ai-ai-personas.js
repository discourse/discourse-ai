import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model() {
    return this.store.findAll("ai-persona");
  },
});
