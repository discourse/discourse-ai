import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import { tracked } from "@glimmer/tracking";

export default class AiFeatureEditor extends Component {
  @service toasts;
  @service currentUser;

  @tracked isSaving = false;

  get formData() {
    return {
      enabled: this.args.model.enabled,
      enable_setting: {
        type: this.args.model.enable_setting?.type,
        value: this.args.model.enable_setting?.value,
      },
      persona: this.args.model.persona.id,
    };
  }

  @action
  async save(formData) {
    this.isSaving = true;

    try {
      console.log("Saving feature data", formData);

      // TODO(@keegan): add save logic (updates setting/personas)

      this.toasts.success({
        data: {
          message: i18n("discourse_ai.features.editor.saved", {
            feature_name: this.args.model.name,
          }),
        },
        duration: 2000,
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
  }

  get enableSettingType() {
    if (this.args.model.enable_setting?.type === "String") {
      return "text";
    }

    return "boolean";
  }

  get personasHint() {
    return i18n("discourse_ai.features.editor.persona_help", {
      config_url: getURL("/admin/plugins/discourse-ai/ai-personas"),
    });
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-features"
      @label="discourse_ai.features.back"
    />

    {{log @model}}
    {{log this.currentUser}}

    <section class="ai-feature-editor__header">
      <h2>{{@model.name}}</h2>
      <p>{{@model.description}}</p>
    </section>

    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="form-horizontal ai-feature-editor"
      as |form data|
    >
      {{log data}}
      {{#if (eq this.enableSettingType "text")}}
        <form.Field
          @name="enable_setting"
          @title={{i18n "discourse_ai.features.enable_setting"}}
          as |field|
        >
          <field.Input />
        </form.Field>
      {{else if (eq this.enableSettingType "boolean")}}
        {{log data.enable_setting.value}}
        <form.Field
          @name="enabled"
          @title={{i18n "discourse_ai.features.editor.enable_setting"}}
          @tooltip={{i18n
            "discourse_ai.features.editor.enable_setting_help"
            setting=data.enable_setting.value
          }}
          @type="boolean"
          as |field|
        >
          <field.Toggle />
        </form.Field>
      {{/if}}

      <form.Field
        @name="persona"
        @title={{i18n "discourse_ai.features.editor.persona"}}
        @format="large"
        @helpText={{htmlSafe this.personasHint}}
        @validation="required"
        as |field|
      >
        <field.Select @includeNone={{false}} as |select|>
          {{#each this.currentUser.ai_enabled_personas as |persona|}}
            <select.Option @value={{persona.id}}>
              {{persona.name}}
            </select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <form.Actions>
        <form.Submit
          @label="discourse_ai.features.editor.save"
          @disabled={{this.isSaving}}
        />
      </form.Actions>
    </Form>
  </template>
}
