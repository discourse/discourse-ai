import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";

export default class AiFeatureEditor extends Component {
  @service toasts;
  @service currentUser;
  @service router;

  @tracked isSaving = false;

  get formData() {
    return {
      enabled: this.args.model.enable_setting?.value,
      persona_id: this.args.model.persona?.id,
    };
  }

  @action
  async save(formData) {
    this.isSaving = true;

    try {
      this.args.model.save({
        enabled: formData.enabled,
        persona_id: parseInt(formData.persona_id, 10),
      });

      this.toasts.success({
        data: {
          message: i18n("discourse_ai.features.editor.saved", {
            feature_name: this.args.model.name,
          }),
        },
        duration: 2000,
      });

      discourseLater(() => {
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-features.index"
        );
      }, 500);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
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
    <section class="ai-feature-editor__header">
      <h2>{{@model.name}}</h2>
      <p>{{@model.description}}</p>
    </section>

    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="form-horizontal ai-feature-editor"
      as |form|
    >
      {{#if (eq @model.enable_setting.type "bool")}}
        <form.Field
          @name="enabled"
          @title={{i18n "discourse_ai.features.editor.enable_setting"}}
          @tooltip={{i18n
            "discourse_ai.features.editor.enable_setting_help"
            setting=@model.enable_setting.name
          }}
          @validation="required"
          @type="boolean"
          as |field|
        >
          <field.Toggle />
        </form.Field>
      {{/if}}

      {{log this.currentUser}}
      <form.Field
        @name="persona_id"
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
