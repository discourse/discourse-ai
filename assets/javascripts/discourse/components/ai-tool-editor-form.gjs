import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { hash } from "@ember/helper";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiToolEditorForm extends Component {
  PARAMETER_TYPES = [
    { name: "string", id: "string" },
    { name: "number", id: "number" },
    { name: "boolean", id: "boolean" },
    { name: "array", id: "array" },
  ];

  @cached
  get formData() {
    // todo
    return {
      name: "initial data",
      parameters: {},
    };
  }

  @action
  async save(data) {
    console.log(data, "is saved!");
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-tool-editor"
      as |form data|
    >
      {{log data}}
      <form.Field
        @name="name"
        @title={{i18n "discourse_ai.tools.name"}}
        @validation="required|length:1,100"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.name_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__name" />
      </form.Field>

      <form.Field
        @name="tool_name"
        @title={{i18n "discourse_ai.tools.tool_name"}}
        @validation="required|length:1,100"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.tool_name_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__tool_name" />
      </form.Field>

      <form.Field
        @name="description"
        @title={{i18n "discourse_ai.tools.description"}}
        @validation="required|length:1,1000"
        @format="full"
        @tooltip={{i18n "discourse_ai.tools.description_help"}}
        as |field|
      >
        <field.Textarea
          @height={{60}}
          class="ai-tool-editor__description"
          placeholder={{i18n "discourse_ai.tools.description_help"}}
        />
      </form.Field>

      <form.Field
        @name="summary"
        @title={{i18n "discourse_ai.tools.summary"}}
        @validation="required|length:1,255"
        @format="large"
        @tooltip={{i18n "discourse_ai.tools.summary_help"}}
        as |field|
      >
        <field.Input class="ai-tool-editor__summary" />
      </form.Field>

      <form.Button
        @icon="plus"
        @label="discourse_ai.tools.add_parameter"
        @action={{fn form.addItemToCollection "foo" (hash bar=3)}}
      />

      <form.Collection @name="foo" as |collection index|>
        <div class="ai-tool-parameter">
          <collection.Field
            @name="parameter_name"
            @title={{i18n "discourse_ai.tools.parameter_name"}}
            as |field|
          >
            <form.InputGroup as |inputGroup|>
              <inputGroup.Field
                @title={{i18n "discourse_ai.tools.parameter_name"}}
                @name="parameter_name"
                as |f|
              >
                <f.Input />
              </inputGroup.Field>
              <inputGroup.Field
                @name="parameter_type"
                @title="Parameter Type"
                @validation="required"
                as |f|
              >
                <f.Menu @selection="todo" as |menu|>
                  {{#each this.PARAMETER_TYPES as |type|}}
                    <menu.Item
                      @value="string"
                      data-type={{type.id}}
                    >{{type.name}}</menu.Item>
                  {{/each}}
                </f.Menu>
              </inputGroup.Field>
            </form.InputGroup>
            <field.Input
              @title={{i18n "discourse_ai.tools.parameter_description"}}
              @name="parameter_description"
            />
            <form.Button @action={{fn collection.remove index}}>
              Remove
            </form.Button>
          </collection.Field>
        </div>
      </form.Collection>

      <form.Actions>
        {{! TODO add delete and test actions when /edit }}
        <form.Submit @label="discourse_ai.tools.save" />
      </form.Actions>
    </Form>
  </template>
}
