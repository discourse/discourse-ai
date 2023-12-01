import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class Sentiment extends Component {
  @service siteSettings;
  @service currentUser;

  get showSentiment() {
    return this.currentUser && this.currentUser.staff;
  }

  get icon() {
    switch(this.args.outletArgs.model.sentiment) {
      case "positive":
        return "smile";
      case "negative":
        return "frown";
      case "neutral":
        return "meh";
      default:
        return "meh";
    }
  }
}
