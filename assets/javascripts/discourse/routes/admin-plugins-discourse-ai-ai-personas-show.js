import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  async model(params) {
    return this.store.find("ai-persona", params.id);
  },
});
