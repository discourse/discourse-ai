import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  const settings = api.container.lookup("service:site-settings");

  if (settings.ai_sentiment_enabled) {
    api.addAdminSidebarSectionLink("reports", {
      name: "sentiment_overview",
      href: "/admin/dashboard/sentiment#sentiment-heading",
      label: "discourse_ai.sentiments.sidebar.overview",
      icon: "chart-column",
    });
    api.addAdminSidebarSectionLink("reports", {
      name: "sentiment_analysis",
      route: "adminReports.show",
      routeModels: ["sentiment_analysis"],
      label: "discourse_ai.sentiments.sidebar.analysis",
      icon: "chart-pie",
    });
  }
});
