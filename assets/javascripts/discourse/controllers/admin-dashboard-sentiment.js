import AdminDashboardTabController from "admin/controllers/admin-dashboard-tab";

export default class AdminDashboardSentiment extends AdminDashboardTabController {
  get emotions() {
    const emotions = [
      "admiration",
      "amusement",
      "anger",
      "annoyance",
      "approval",
      "caring",
      "confusion",
      "curiosity",
      "desire",
      "disappointment",
      "disapproval",
      "disgust",
      "embarrassment",
      "excitement",
      "fear",
      "gratitude",
      "grief",
      "joy",
      "love",
      "nervousness",
      "neutral",
      "optimism",
      "pride",
      "realization",
      "relief",
      "remorse",
      "sadness",
      "surprise",
    ];
    return emotions;
  }
}
