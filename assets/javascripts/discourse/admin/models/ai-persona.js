import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "description",
  "tools",
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
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "question_consolidator_llm",
  "allow_chat",
  "tool_details",
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
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "question_consolidator_llm",
  "allow_chat",
  "tool_details",
];

class ToolOption {
  @tracked value = null;
}

export default class AiPersona extends RestModel {
  // this code is here to convert the wire schema to easier to work with object
  // on the wire we pass in/out tools as an Array.
  // [[ToolName, {option1: value, option2: value}, force], ToolName2, ToolName3]
  // So we rework this into a "tools" property and nested toolOptions
  init(properties) {
    this.forcedTools = [];
    if (properties.tools) {
      properties.tools = properties.tools.map((tool) => {
        if (typeof tool === "string") {
          return tool;
        } else {
          let [toolId, options, force] = tool;
          for (let optionId in options) {
            if (!options.hasOwnProperty(optionId)) {
              continue;
            }
            this.getToolOption(toolId, optionId).value = options[optionId];
          }
          if (force) {
            this.forcedTools.push(toolId);
          }
          return toolId;
        }
      });
    }
    super.init(properties);
    this.tools = properties.tools;
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

  getToolOption(toolId, optionId) {
    this.toolOptions ||= {};
    this.toolOptions[toolId] ||= {};
    return (this.toolOptions[toolId][optionId] ||= new ToolOption());
  }

  populateToolOptions(attrs) {
    if (!attrs.tools) {
      return;
    }
    let toolsWithOptions = [];
    attrs.tools.forEach((toolId) => {
      if (typeof toolId !== "string") {
        toolId = toolId[0];
      }

      let force = this.forcedTools.includes(toolId);
      if (this.toolOptions && this.toolOptions[toolId]) {
        let options = this.toolOptions[toolId];
        let optionsWithValues = {};
        for (let optionId in options) {
          if (!options.hasOwnProperty(optionId)) {
            continue;
          }
          let option = options[optionId];
          optionsWithValues[optionId] = option.value;
        }
        toolsWithOptions.push([toolId, optionsWithValues, force]);
      } else {
        toolsWithOptions.push([toolId, {}, force]);
      }
    });
    attrs.tools = toolsWithOptions;
  }

  updateProperties() {
    let attrs = this.system
      ? this.getProperties(SYSTEM_ATTRIBUTES)
      : this.getProperties(CREATE_ATTRIBUTES);
    attrs.id = this.id;
    this.populateToolOptions(attrs);
    return attrs;
  }

  createProperties() {
    let attrs = this.getProperties(CREATE_ATTRIBUTES);
    this.populateToolOptions(attrs);
    return attrs;
  }

  workingCopy() {
    let attrs = this.getProperties(CREATE_ATTRIBUTES);
    this.populateToolOptions(attrs);

    const persona = AiPersona.create(attrs);
    persona.forcedTools = (this.forcedTools || []).slice();
    return persona;
  }
}
