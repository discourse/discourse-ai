import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

export default class AiPersonaToolOptions extends Component {
  get showToolOptions() {
    const allTools = this.args.allTools;
    if (!allTools || !this.args.data.tools) {
      return false;
    }
    return this.args.data?.tools.any(
      (tool) => allTools.findBy("id", tool)?.options
    );
  }

  get toolsMetadata() {
    const metatada = {};

    this.args.allTools.map((t) => {
      metatada[t.id] = {
        name: t.name,
        ...t?.options,
      };
    });

    return metatada;
  }

  @action
  formObjectKeys(toolOptions) {
    return toolOptions ? Object.keys(toolOptions) : [];
  }

  <template>
    {{#if this.showToolOptions}}
      <@form.Container
        @title={{i18n "discourse_ai.ai_persona.tool_options"}}
        @direction="column"
        @format="full"
      >
        <@form.Object
          @name="toolOptions"
          @title={{i18n "discourse_ai.ai_persona.tool_options"}}
          as |toolObj optsPerTool|
        >
          {{#each (this.formObjectKeys optsPerTool) as |toolId|}}
            <div class="ai-persona-editor__tool-options">
              {{#let (get this.toolsMetadata toolId) as |toolMeta|}}
                <div class="ai-persona-editor__tool-options-name">
                  {{toolMeta.name}}
                </div>
                <toolObj.Object @name={{toolId}} as |optionsObj optionData|>
                  {{#each (this.formObjectKeys optionData) as |optionName|}}
                    {{#let (get toolMeta optionName) as |optionMeta|}}
                      <optionsObj.Field
                        @name={{optionName}}
                        @title={{optionMeta.name}}
                        @helpText={{optionMeta.description}}
                        @format="full"
                        as |field|
                      >
                        {{#if (eq optionMeta.type "enum")}}
                          <field.Select @includeNone={{false}} as |select|>
                            {{#each optionsObj.values as |v|}}
                              <select.Option @value={{v}}>{{v}}</select.Option>
                            {{/each}}
                          </field.Select>
                        {{else if (eq optionMeta.type "llm")}}
                          <field.Custom>
                            <AiLlmSelector
                              @value={{field.value}}
                              @llms={{@llms}}
                              @onChange={{field.set}}
                              @class="ai-persona-tool-option-editor__llms"
                            />
                          </field.Custom>
                        {{else if (eq optionMeta.type "boolean")}}
                          <field.Checkbox />
                        {{else}}
                          <field.Input />
                        {{/if}}
                      </optionsObj.Field>
                    {{/let}}
                  {{/each}}
                </toolObj.Object>
              {{/let}}
            </div>
          {{/each}}
        </@form.Object>
      </@form.Container>
    {{/if}}
  </template>
}
