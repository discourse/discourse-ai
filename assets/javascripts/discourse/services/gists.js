import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

export default class Gists extends Service {
  @service router;

  @tracked preference = localStorage.getItem("topicListLayout");

  get shouldShow() {
    const currentRoute = this.router.currentRoute.name;
    const isDiscovery = currentRoute.includes("discovery");
    const isNotCategories = !currentRoute.includes("categories");
    const gistsAvailable =
      this.router.currentRoute.attributes?.list?.topics?.some(
        (topic) => topic.ai_topic_gist
      );

    return isDiscovery && isNotCategories && gistsAvailable;
  }

  setPreference(value) {
    this.preference = value;
    localStorage.setItem("topicListLayout", value);

    if (this.preference === "table-ai") {
      localStorage.setItem("aiPreferred", true);
    }
  }
}
