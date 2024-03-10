export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-ai", { path: "/" }, function () {
      this.route("ai-personas", function () {
        this.route("new");
        this.route("show", { path: "/:id" });
      });
    });
  },
};
