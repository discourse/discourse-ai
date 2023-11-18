import RestModel from "discourse/models/rest";

const ATTRIBUTES = [
  "name",
  "description",
  "commands",
  "system_prompt",
  "allowed_group_ids",
  "enabled",
  "system",
];

export default class AiPersona extends RestModel {
  updateProperties() {
    let attrs = this.getProperties(ATTRIBUTES);
    attrs.id = this.id;
    return attrs;
  }

  createProperties() {
    return this.getProperties(ATTRIBUTES);
  }
}
