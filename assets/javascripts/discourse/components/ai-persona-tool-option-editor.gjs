import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class AiPersonaToolOptionEditor extends Component {
  get isBoolean() {
    return this.args.option.type === "boolean";
  }

  get selectedValue() {
    return this.args.option.value.value === "true";
  }

  @action
  onCheckboxChange(event) {
    this.args.option.value.value = event.target.checked ? "true" : "false";
  }

  <template>
    <div class="control-group ai-persona-tool-option-editor">
      <label>
        {{@option.name}}
      </label>
      <div class="">
        {{#if this.isBoolean}}
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
