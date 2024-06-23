import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

const PARAMETER_TYPES = ["string", "number", "boolean", "array"];

export default class AiToolParameterEditor extends Component {
  @tracked parameters = [];

  constructor() {
    super(...arguments);
    this.parameters = this.args.parameters || [];
  }

  @action
  addParameter() {
    this.parameters.pushObject({
      name: "",
      description: "",
      type: "string",
      required: false,
      enum: false,
      enumValues: [],
    });
  }

  @action
  removeParameter(parameter) {
    this.parameters.removeObject(parameter);
  }

  @action
  updateParameter(parameter, field, value) {
    parameter[field] = value;
    this.args.onChange(this.parameters);
  }

  @action
  toggleEnum(parameter) {
    parameter.enum = !parameter.enum;
    if (!parameter.enum) {
      parameter.enumValues = [];
    }
    this.args.onChange(this.parameters);
  }

  @action
  addEnumValue(parameter) {
    parameter.enumValues.pushObject("");
    this.args.onChange(this.parameters);
  }

  @action
  removeEnumValue(parameter, index) {
    parameter.enumValues.removeAt(index);
    this.args.onChange(this.parameters);
  }

  <template>
    {{#each this.parameters as |parameter|}}
      <div class="ai-tool-parameter">
        <div class="parameter-row">
          <Input
            @type="text"
            @value={{parameter.name}}
            placeholder={{I18n.t "discourse_ai.tools.parameter_name"}}
            {{on
              "input"
              (fn this.updateParameter parameter "name" value="target.value")
            }}
          />
          <ComboBox
            @value={{parameter.type}}
            @content={{PARAMETER_TYPES}}
            @onChange={{fn this.updateParameter parameter "type"}}
          />
          <DButton
            @icon="trash-alt"
            @action={{fn this.removeParameter parameter}}
            class="btn-danger"
          />
        </div>
        <div class="parameter-row">
          <Input
            @type="text"
            @value={{parameter.description}}
            placeholder={{I18n.t "discourse_ai.tools.parameter_description"}}
            {{on
              "input"
              (fn
                this.updateParameter
                parameter
                "description"
                value="target.value"
              )
            }}
          />
        </div>
        <div class="parameter-row">
          <label>
            <Input
              @type="checkbox"
              @checked={{parameter.required}}
              {{on
                "change"
                (fn
                  this.updateParameter
                  parameter
                  "required"
                  value="target.checked"
                )
              }}
            />
            {{I18n.t "discourse_ai.tools.parameter_required"}}
          </label>
          <label>
            <Input
              @type="checkbox"
              @checked={{parameter.enum}}
              {{on "change" (fn this.toggleEnum parameter)}}
            />
            {{I18n.t "discourse_ai.tools.parameter_enum"}}
          </label>
        </div>
        {{#if parameter.enum}}
          <div class="parameter-enum-values">
            {{#each parameter.enumValues as |enumValue enumIndex|}}
              <div class="enum-value-row">
                <Input
                  @type="text"
                  @value={{enumValue}}
                  placeholder={{I18n.t "discourse_ai.tools.enum_value"}}
                  {{on
                    "input"
                    (fn
                      this.updateParameter
                      parameter.enumValues
                      enumIndex
                      value="target.value"
                    )
                  }}
                />
                <DButton
                  @icon="trash-alt"
                  @action={{fn this.removeEnumValue parameter enumIndex}}
                  class="btn-danger"
                />
              </div>
            {{/each}}
            <DButton
              @icon="plus"
              @action={{fn this.addEnumValue parameter}}
              @label="discourse_ai.tools.add_enum_value"
            />
          </div>
        {{/if}}
      </div>
    {{/each}}
    <DButton
      @icon="plus"
      @action={{this.addParameter}}
      @label="discourse_ai.tools.add_parameter"
    />
  </template>
}
