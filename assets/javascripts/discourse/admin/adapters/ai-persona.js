import RestAdapter from "discourse/adapters/rest";

export default class Adapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/discourse-ai/";
  }

  pathFor() {
    return super.pathFor(...arguments) + ".json";
  }

  apiNameFor() {
    return "ai-persona";
  }
}
