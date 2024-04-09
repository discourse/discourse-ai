import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const ATTRIBUTES = [
  "id",
  "name",
  "description",
  "commands",
  "system_prompt",
  "allowed_group_ids",
  "enabled",
  "system",
  "priority",
  "top_p",
  "temperature",
  "user_id",
  "mentionable",
  "default_llm",
  "user",
  "max_context_posts",
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
];

const SYSTEM_ATTRIBUTES = [
  "id",
  "allowed_group_ids",
  "enabled",
  "system",
  "priority",
  "user_id",
  "mentionable",
  "default_llm",
  "user",
  "max_context_posts",
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
];

class CommandOption {
  @tracked value = null;
}

export default class AiPersona extends RestModel {
  // this code is here to convert the wire schema to easier to work with object
  // on the wire we pass in/out commands as an Array.
  // [[CommandName, {option1: value, option2: value}], CommandName2, CommandName3]
  // So we rework this into a "commands" property and nested commandOptions
  init(properties) {
    if (properties.commands) {
      properties.commands = properties.commands.map((command) => {
        if (typeof command === "string") {
          return command;
        } else {
          let [commandId, options] = command;
          for (let optionId in options) {
            if (!options.hasOwnProperty(optionId)) {
              continue;
            }
            this.getCommandOption(commandId, optionId).value =
              options[optionId];
          }
          return commandId;
        }
      });
    }
    super.init(properties);
    this.commands = properties.commands;
  }

  async createUser() {
    const result = await ajax(
      `/admin/plugins/discourse-ai/ai-personas/${this.id}/create-user.json`,
      {
        type: "POST",
      }
    );
    this.user = result.user;
    this.user_id = this.user.id;
    return this.user;
  }

  getCommandOption(commandId, optionId) {
    this.commandOptions ||= {};
    this.commandOptions[commandId] ||= {};
    return (this.commandOptions[commandId][optionId] ||= new CommandOption());
  }

  populateCommandOptions(attrs) {
    if (!attrs.commands) {
      return;
    }
    let commandsWithOptions = [];
    attrs.commands.forEach((commandId) => {
      if (typeof commandId !== "string") {
        commandId = commandId[0];
      }
      if (this.commandOptions && this.commandOptions[commandId]) {
        let options = this.commandOptions[commandId];
        let optionsWithValues = {};
        for (let optionId in options) {
          if (!options.hasOwnProperty(optionId)) {
            continue;
          }
          let option = options[optionId];
          optionsWithValues[optionId] = option.value;
        }
        commandsWithOptions.push([commandId, optionsWithValues]);
      } else {
        commandsWithOptions.push(commandId);
      }
    });
    attrs.commands = commandsWithOptions;
  }

  updateProperties() {
    let attrs = this.system
      ? this.getProperties(SYSTEM_ATTRIBUTES)
      : this.getProperties(ATTRIBUTES);
    attrs.id = this.id;
    this.populateCommandOptions(attrs);
    return attrs;
  }

  createProperties() {
    let attrs = this.getProperties(ATTRIBUTES);
    this.populateCommandOptions(attrs);
    return attrs;
  }

  workingCopy() {
    return AiPersona.create(this.createProperties());
  }
}
