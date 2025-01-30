import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

export default class AiPersonaToolOptionEditor extends Component {
  get isBoolean() {
    return this.args.option.type === "boolean";
  }

  get isEnum() {
    return this.args.option.type === "enum";
  }

  get isLlm() {
    return this.args.option.type === "llm";
  }

  get selectedValue() {
    return this.args.option.value.value === "true";
  }

  get selectedLlm() {
    if (this.args.option.value.value) {
      return `custom:${this.args.option.value.value}`;
    } else {
      return "blank";
    }
  }

  set selectedLlm(value) {
    if (value === "blank") {
      this.args.option.value.value = null;
    } else {
      this.args.option.value.value = value.replace("custom:", "");
    }
  }

  @action
  onCheckboxChange(event) {
    this.args.option.value.value = event.target.checked ? "true" : "false";
  }

  @action
  onSelectOption(event) {
    this.args.option.value.value = event.target.value;
  }

  <template>
    <div class="control-group ai-persona-tool-option-editor">
      <label>
        {{@option.name}}
      </label>
      <div class="">
        {{#if this.isEnum}}
          <select name="input" {{on "change" this.onSelectOption}}>
            {{#each this.args.option.values as |value|}}
              <option
                value={{value}}
                selected={{eq value this.args.option.value.value}}
              >
                {{value}}
              </option>
            {{/each}}
          </select>
        {{else if this.isLlm}}
          <AiLlmSelector
            class="ai-persona-tool-option-editor__llms"
            @value={{this.selectedLlm}}
            @llms={{@llms}}
            @blankName={{i18n "discourse_ai.ai_persona.use_parent_llm"}}
          />
        {{else if this.isBoolean}}
          <input
            type="checkbox"
            checked={{this.selectedValue}}
            {{on "click" this.onCheckboxChange}}
          />
          {{@option.description}}
        {{else}}
          <Input @value={{@option.value.value}} />
        {{/if}}
      </div>
      {{#unless this.isBoolean}}
        <div class="ai-persona-tool-option-editor__instructions">
          {{@option.description}}
        </div>
      {{/unless}}
    </div>
  </template>
}
