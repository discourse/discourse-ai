import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const PARAMETER_TYPES = [
  { name: "string", id: "string" },
  { name: "number", id: "number" },
  { name: "boolean", id: "boolean" },
  { name: "array", id: "array" },
];

export default class AiToolParameterEditor extends Component {
  @action
  addParameter() {
    this.args.parameters.push(
      new TrackedObject({
        name: "",
        description: "",
        type: "string",
        required: false,
        enum: null,
      })
    );
  }

  @action
  removeParameter(parameter) {
    const index = this.args.parameters.indexOf(parameter);
    this.args.parameters.splice(index, 1);
  }

  @action
  toggleRequired(parameter, event) {
    parameter.required = event.target.checked;
  }

  @action
  toggleEnum(parameter) {
    if (parameter.enum) {
      parameter.enum = null;
    } else {
      this.addEnumValue(parameter);
    }
  }

  @action
  addEnumValue(parameter) {
    parameter.enum ||= new TrackedArray();
    parameter.enum.push("");
  }

  @action
  removeEnumValue(parameter, index) {
    parameter.enum.splice(index, 1);
    if (parameter.enum.length === 0) {
      parameter.enum = null;
    }
  }

  @action
  updateEnumValue(parameter, index, event) {
    parameter.enum[index] = event.target.value;
  }

  <template>
    {{#each @parameters as |parameter|}}
      <div class="ai-tool-parameter">
        <div class="parameter-row">
          <input
            {{on "input" (withEventValue (fn (mut parameter.name)))}}
            value={{parameter.name}}
            type="text"
            placeholder={{I18n.t "discourse_ai.tools.parameter_name"}}
          />
          <ComboBox @value={{parameter.type}} @content={{PARAMETER_TYPES}} />
        </div>

        <div class="parameter-row">
          <input
            {{on "input" (withEventValue (fn (mut parameter.description)))}}
            value={{parameter.description}}
            type="text"
            placeholder={{I18n.t "discourse_ai.tools.parameter_description"}}
          />
        </div>

        <div class="parameter-row">
          <label>
            <input
              {{on "input" (fn this.toggleRequired parameter)}}
              checked={{parameter.required}}
              type="checkbox"
              class="parameter-row__required-toggle"
            />
            {{I18n.t "discourse_ai.tools.parameter_required"}}
          </label>

          <label>
            <input
              {{on "input" (fn this.toggleEnum parameter)}}
              checked={{parameter.enum}}
              type="checkbox"
              class="parameter-row__enum-toggle"
            />
            {{I18n.t "discourse_ai.tools.parameter_enum"}}
          </label>

          <DButton
            @action={{fn this.removeParameter parameter}}
            @icon="trash-can"
            class="btn-danger"
          />
        </div>

        {{#if parameter.enum}}
          <div class="parameter-enum-values">
            {{#each parameter.enum as |enumValue enumIndex|}}
              <div class="enum-value-row">
                <input
                  {{on "change" (fn this.updateEnumValue parameter enumIndex)}}
                  value={{enumValue}}
                  type="text"
                  placeholder={{I18n.t "discourse_ai.tools.enum_value"}}
                />
                <DButton
                  @action={{fn this.removeEnumValue parameter enumIndex}}
                  @icon="trash-can"
                  class="btn-danger"
                />
              </div>
            {{/each}}

            <DButton
              @action={{fn this.addEnumValue parameter}}
              @label="discourse_ai.tools.add_enum_value"
              @icon="plus"
            />
          </div>
        {{/if}}
      </div>
    {{/each}}

    <DButton
      @action={{this.addParameter}}
      @label="discourse_ai.tools.add_parameter"
      @icon="plus"
    />
  </template>
}
