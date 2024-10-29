import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class GistPreference extends Service {
  @tracked
  preference = localStorage.getItem("aiGistPreference") || "gists_disabled";

  setPreference(value) {
    this.preference = value;
    localStorage.setItem("aiGistPreference", value);
  }
}
