import RestModel from "discourse/models/rest";

const ATTRIBUTES = [
  "name",
  "description",
  "commands",
  "system_prompt",
  "allowed_group_ids",
  "enabled",
  "system",
  "priority",
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

  get sortKey() {
    let prefix = (this.priority || 0) === 0 ? "Z" : "A";
    return prefix + this.name;
  }
}
