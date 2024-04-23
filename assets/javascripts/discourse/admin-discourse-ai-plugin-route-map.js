export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-ai-personas", { path: "ai-personas" }, function () {
      this.route("new");
      this.route("show", { path: "/:id" });
    });
  },
};
