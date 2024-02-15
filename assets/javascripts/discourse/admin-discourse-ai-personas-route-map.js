export default {
  resource: "admin.adminPlugins",

  path: "/plugins",

  map() {
    this.route("discourse-ai", function () {
      this.route("ai-personas", function () {
        this.route("new");
        this.route("show", { path: "/:id" });
      });
    });
  },
};
