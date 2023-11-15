import RestModel from "discourse/models/rest";

const ATTRIBUTES = [
  "name",
  "description",
  "commands",
  "system_prompt",
  "allowed_group_ids",
  "enabled",
];

export default class AiPersona extends RestModel {
  updateProperties() {
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      commands: this.commands,
      system_prompt: this.system_prompt,
      allowed_group_ids: this.allowed_group_ids,
      enabled: this.enabled,
    };
  }

  createProperties() {
    return this.getProperties(ATTRIBUTES);
  }
}
