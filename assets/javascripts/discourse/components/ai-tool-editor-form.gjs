import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import RagOptions from "./rag-options";
import RagUploader from "./rag-uploader";

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
      name: "",
      tool_name: "",
      description: "",
      summary: "",
      parameters: [],
      script: "",
    };
  }

  @action
  async save(data) {
    console.log(data, "is saved!");
  }

  currentParameterSelection(data, index) {
    return data.parameters[index].type;
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-tool-editor"
      as |form data|
    >
      {{log data}}

      {{! NAME }}
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

      {{! TOOL NAME }}
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

      {{! DESCRIPTION }}
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

      {{! SUMMARY }}
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

      {{! PARAMETERS }}
      <form.Collection @name="parameters" as |collection index|>
        <div class="ai-tool-parameter">
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <collection.Field
                @name="name"
                @title={{i18n "discourse_ai.tools.parameter_name"}}
                @validation="required|length:1,100"
                as |field|
              >
                <field.Input />
              </collection.Field>
            </row.Col>

            <row.Col @size={{6}}>
              <collection.Field
                @name="type"
                @title={{i18n "discourse_ai.tools.parameter_type"}}
                @validation="required"
                as |field|
              >
                <field.Menu
                  @selection={{this.currentParameterSelection data index}}
                  as |menu|
                >
                  {{#each this.PARAMETER_TYPES as |type|}}
                    <menu.Item
                      @value={{type.id}}
                      data-type={{type.id}}
                    >{{type.name}}</menu.Item>
                  {{/each}}
                </field.Menu>
              </collection.Field>
            </row.Col>
          </form.Row>

          <collection.Field
            @name="description"
            @title={{i18n "discourse_ai.tools.parameter_description"}}
            @validation="required|length:1,1000"
            as |field|
          >
            <field.Input class="ai-tool-editor__parameter-description" />
          </collection.Field>

          <form.Row as |row|>
            <row.Col @size={{4}}>
              <collection.Field @name="required" @title="Required" as |field|>
                <field.Checkbox />
              </collection.Field>
            </row.Col>

            <row.Col @size={{4}}>
              <collection.Field @name="enum" @title="Enum" as |field|>
                <field.Checkbox />
              </collection.Field>
            </row.Col>

            <row.Col @size={{4}} class="ai-tool-parameter-actions">
              <form.Button
                @label="discourse_ai.tools.remove_parameter"
                @icon="trash-can"
                @action={{fn collection.remove index}}
                class="btn-danger"
              />
            </row.Col>
          </form.Row>
        </div>
      </form.Collection>

      <form.Button
        @icon="plus"
        @label="discourse_ai.tools.add_parameter"
        @action={{fn
          form.addItemToCollection
          "parameters"
          (hash name="" type="string" description="" required=false enum=false)
        }}
      />

      {{! SCRIPT }}
      <form.Field
        @name="script"
        @title={{i18n "discourse_ai.tools.script"}}
        @validation="required|length:1,100000"
        @format="full"
        as |field|
      >
        <field.Code @lang="javascript" @height={{400}} />
      </form.Field>

      {{! Uploads }}
      <form.Field
        @name="uploads"
        @title={{i18n "discourse_ai.rag.uploads.title"}}
        as |field|
      >
        <field.Custom>
          {{! TODO: props for RagUploader and RagOptions }}
          <RagUploader
            @target={{this.editingModel}}
            @updateUploads={{this.updateUploads}}
            @onRemove={{this.removeUpload}}
            @allowImages={{@settings.rag_images_enabled}}
          />
          <RagOptions
            @model={{this.editingModel}}
            @llms={{@llms}}
            @allowImages={{@settings.rag_images_enabled}}
          />
        </field.Custom>
      </form.Field>

      <form.Actions>
        {{! TODO add delete and test actions when /edit }}
        <form.Submit @label="discourse_ai.tools.save" />
      </form.Actions>
    </Form>
  </template>
}
