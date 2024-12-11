export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-ai-personas", { path: "ai-personas" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id" });
    });

    this.route("discourse-ai-llms", { path: "ai-llms" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id" });
    });

    this.route("discourse-ai-tools", { path: "ai-tools" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id" });
    });
    this.route("discourse-ai-usage", { path: "ai-usage" });
  },
};
