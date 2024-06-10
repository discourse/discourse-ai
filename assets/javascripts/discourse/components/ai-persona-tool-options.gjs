import Component from "@glimmer/component";
import I18n from "discourse-i18n";
import AiPersonaToolOptionEditor from "./ai-persona-tool-option-editor";

export default class AiPersonaToolOptions extends Component {
  get showToolOptions() {
    const allTools = this.args.allTools;
    if (!allTools) {
      return false;
    }

    return this.toolNames.any(
      (tool) => allTools.find((c) => c.id === tool)?.options
    );
  }

  get toolNames() {
    if (!this.args.tools) {
      return [];
    }
    return this.args.tools.map((tool) => {
      if (typeof tool === "string") {
        return tool;
      } else {
        return tool[0];
      }
    });
  }

  get toolOptions() {
    if (!this.args.tools) {
      return [];
    }

    const allTools = this.args.allTools;
    if (!allTools) {
      return [];
    }

    const options = [];
    this.toolNames.forEach((toolId) => {
      const tool = allTools.find((c) => c.id === toolId);

      const toolName = tool?.name;
      const toolOptions = tool?.options;

      if (toolOptions) {
        const mappedOptions = Object.keys(toolOptions).map((key) => {
          const value = this.args.persona.getToolOption(toolId, key);
          return Object.assign({}, toolOptions[key], { id: key, value });
        });

        options.push({ toolName, options: mappedOptions });
      }
    });

    return options;
  }

  <template>
    {{#if this.showToolOptions}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.tool_options"}}</label>
        <div>
          {{#each this.toolOptions as |toolOption|}}
            <div class="ai-persona-editor__tool-options">
              <div class="ai-persona-editor__tool-options-name">
                {{toolOption.toolName}}
              </div>
              <div class="ai-persona-editor__tool-option-options">
                {{#each toolOption.options as |option|}}
                  <AiPersonaToolOptionEditor @option={{option}} />
                {{/each}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
