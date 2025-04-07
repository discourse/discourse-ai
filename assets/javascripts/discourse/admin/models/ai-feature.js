import RestModel from "discourse/models/rest";

export default class AiFeature extends RestModel {
  createProperties() {
    return this.getProperties(
      "id",
      "name",
      "description",
      "enable_setting",
      "persona",
      "persona_setting",
      "additional_settings"
    );
  }
}
