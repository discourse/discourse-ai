import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import RestModel from "discourse/models/rest";

export default class AiFeature extends RestModel {
  createProperties() {
    return this.getProperties(
      "id",
      "name",
      "description",
      "enabled",
      "enable_setting",
      "persona"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();

    // TODO: add the ones to update
    // i.e. attrs.id = this.id;

    return attrs;
  }
}
