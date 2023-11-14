import RestModel from "discourse/models/rest";

const ATTRIBUTES = ["name", "description", "commands", "system_prompt"];

export default class AiPersona extends RestModel {
  updateProperties() {
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      commands: this.commands,
      system_prompt: this.system_prompt,
    };
  }

  createProperties() {
    return this.getProperties(ATTRIBUTES);
  }
}
