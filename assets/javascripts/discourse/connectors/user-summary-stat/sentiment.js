import Component from "@glimmer/component";

export default class Sentiment extends Component {
  static shouldRender(outletArgs, helper) {
    return (
      helper.siteSettings.ai_sentiment_enabled &&
      helper.siteSettings.ai_sentiment_show_sentiment_public_profile &&
      outletArgs.model.sentiment &&
      helper.currentUser &&
      helper.currentUser.staff
    );
  }

  get icon() {
    switch (this.args.outletArgs.model.sentiment) {
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
