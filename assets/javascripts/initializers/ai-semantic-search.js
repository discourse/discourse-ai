import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.15.0", (api) => {
  api.modifyClass("component:search-result-entry", {
    pluginId: "discourse-ai",

    classNameBindings: ["bulkSelectEnabled", "post.generatedByAI:ai-result"],
  });

  api.addSearchMenuAssistantSelectCallback((args) => {
    console.log("args", args);
    if (args.usage !== "recent-search") {
      return true;
    }
    args.searchTermChanged(args.updatedTerm);
    return false;
  });
});
