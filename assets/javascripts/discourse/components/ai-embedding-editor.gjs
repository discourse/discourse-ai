import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminSectionLandingItem from "admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "admin/components/admin-section-landing-wrapper";
import ComboBox from "select-kit/components/combo-box";
import DTooltip from "float-kit/components/d-tooltip";
import not from "truth-helpers/helpers/not";

export default class AiEmbeddingEditor extends Component {
  @service toasts;
  @service router;
  @service dialog;
  @service store;

  @tracked isSaving = false;
  @tracked selectedPreset = null;

  @tracked testRunning = false;
  @tracked testResult = null;
  @tracked testError = null;
  @tracked apiKeySecret = true;
  @tracked editingModel = null;

  get selectedProviders() {
    const t = (provName) => {
      return i18n(`discourse_ai.embeddings.providers.${provName}`);
    };

    return this.args.embeddings.resultSetMeta.providers.map((prov) => {
      return { id: prov, name: t(prov) };
    });
  }

  get distanceFunctions() {
    const t = (df) => {
      return i18n(`discourse_ai.embeddings.distance_functions.${df}`);
    };

    return this.args.embeddings.resultSetMeta.distance_functions.map((df) => {
      let iconName;

      if (df === "<=>") {
        iconName = "discourse-spaceship-operator";
      } else if (df === "<#>") {
        iconName = "discourse-negative-inner-product";
      }

      return {
        id: df,
        name: t(df),
        icon: iconName, // Generate the icon helper output
      };
    });
  }

  get presets() {
    const presets = this.args.embeddings.resultSetMeta.presets.map((preset) => {
      return {
        name: preset.display_name,
        id: preset.preset_id,
        provider: preset.provider,
      };
    });

    presets.unshiftObject({
      name: i18n("discourse_ai.embeddings.configure_manually"),
      id: "manual",
      provider: "fake",
    });

    return presets;
  }

  get showPresets() {
    return !this.selectedPreset && this.args.model.isNew;
  }

  @computed("editingModel.provider")
  get metaProviderParams() {
    return (
      this.args.embeddings.resultSetMeta.provider_params[
        this.editingModel?.provider
      ] || {}
    );
  }

  get testErrorMessage() {
    return i18n("discourse_ai.llms.tests.failure", { error: this.testError });
  }

  get displayTestResult() {
    return this.testRunning || this.testResult !== null;
  }

  @action
  configurePreset(preset) {
    this.selectedPreset =
      this.args.embeddings.resultSetMeta.presets.findBy(
        "preset_id",
        preset.id
      ) || {};

    this.editingModel = this.store
      .createRecord("ai-embedding", this.selectedPreset)
      .workingCopy();
  }

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
  }

  @action
  makeApiKeySecret() {
    this.apiKeySecret = true;
  }

  @action
  toggleApiKeySecret() {
    this.apiKeySecret = !this.apiKeySecret;
  }

  @action
  async save() {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    try {
      await this.editingModel.save();

      if (isNew) {
        this.args.embeddings.addObject(this.editingModel);
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-embeddings.index"
        );
      } else {
        this.toasts.success({
          data: { message: i18n("discourse_ai.embeddings.saved") },
          duration: 2000,
        });
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  @action
  async test() {
    this.testRunning = true;

    try {
      const configTestResult = await this.editingModel.testConfig();
      this.testResult = configTestResult.success;

      if (this.testResult) {
        this.testError = null;
      } else {
        this.testError = configTestResult.error;
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.testRunning = false;
      }, 1000);
    }
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.embeddings.confirm_delete"),
      didConfirm: () => {
        return this.args.model
          .destroyRecord()
          .then(() => {
            this.args.llms.removeObject(this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-embeddings.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  resetForm() {
    this.selectedPreset = null;
    this.editingModel = null;
  }

  <template>
    <form
      {{didInsert this.updateModel @model.id}}
      {{didUpdate this.updateModel @model.id}}
      class="form-horizontal ai-embedding-editor"
    >
      {{#if this.showPresets}}
        <BackButton
          @route="adminPlugins.show.discourse-ai-embeddings"
          @label="discourse_ai.embeddings.back"
        />
        <div class="control-group">
          <h2>{{i18n "discourse_ai.embeddings.presets"}}</h2>
          <AdminSectionLandingWrapper>
            {{#each this.presets as |preset|}}
              <AdminSectionLandingItem
                @titleLabelTranslated={{preset.name}}
                @taglineLabel={{concat
                  "discourse_ai.embeddings.providers."
                  preset.provider
                }}
                data-preset-id={{preset.id}}
                class="ai-llms-list-editor__templates-list-item"
              >
                <:buttons as |buttons|>
                  <buttons.Default
                    @action={{fn this.configurePreset preset}}
                    @icon="gear"
                    @label="discourse_ai.llms.preconfigured.button"
                  />
                </:buttons>
              </AdminSectionLandingItem>

            {{/each}}
          </AdminSectionLandingWrapper>

        </div>

      {{else}}
        {{#if this.editingModel.isNew}}
          <DButton
            @action={{this.resetForm}}
            @label="back_button"
            @icon="chevron-left"
            class="btn-flat back-button"
          />
        {{else}}
          <BackButton
            @route="adminPlugins.show.discourse-ai-embeddings"
            @label="discourse_ai.embeddings.back"
          />
        {{/if}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.display_name"}}</label>
          <Input
            class="ai-embedding-editor-input ai-embedding-editor__display-name"
            @type="text"
            @value={{this.editingModel.display_name}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.provider"}}</label>
          <ComboBox
            @value={{this.editingModel.provider}}
            @content={{this.selectedProviders}}
            @class="ai-embedding-editor__provider"
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.url"}}</label>
          <Input
            class="ai-embedding-editor-input ai-embedding-editor__url"
            @type="text"
            @value={{this.editingModel.url}}
            required="true"
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.api_key"}}</label>
          <div class="ai-embedding-editor__secret-api-key-group">
            <Input
              @value={{this.editingModel.api_key}}
              class="ai-embedding-editor-input ai-embedding-editor__api-key"
              @type={{if this.apiKeySecret "password" "text"}}
              required="true"
              {{on "focusout" this.makeApiKeySecret}}
            />
            <DButton
              @action={{this.toggleApiKeySecret}}
              @icon="far-eye-slash"
            />
          </div>
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.tokenizer"}}</label>
          <ComboBox
            @value={{this.editingModel.tokenizer_class}}
            @content={{@embeddings.resultSetMeta.tokenizers}}
            @class="ai-embedding-editor__tokenizer"
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.dimensions"}}</label>
          <Input
            @type="number"
            class="ai-embedding-editor-input ai-embedding-editor__dimensions"
            step="any"
            min="0"
            lang="en"
            @value={{this.editingModel.dimensions}}
            required="true"
            disabled={{not this.editingModel.isNew}}
          />
          {{#if this.editingModel.isNew}}
            <DTooltip
              @icon="circle-exclamation"
              @content={{i18n
                "discourse_ai.embeddings.hints.dimensions_warning"
              }}
            />
          {{/if}}
        </div>

        <div class="control-group ai-embedding-editor__matryoshka_dimensions">
          <Input
            @type="checkbox"
            @checked={{this.editingModel.matryoshka_dimensions}}
          />
          <label>{{i18n "discourse_ai.embeddings.matryoshka_dimensions"}}
          </label>
          <DTooltip
            @icon="circle-question"
            @content={{i18n
              "discourse_ai.embeddings.hints.matryoshka_dimensions"
            }}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.embed_prompt"}}</label>
          <Textarea
            class="ai-embedding-editor-input ai-embedding-editor__embed_prompt"
            @value={{this.editingModel.embed_prompt}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.embeddings.hints.embed_prompt"}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.search_prompt"}}</label>
          <Textarea
            class="ai-embedding-editor-input ai-embedding-editor__search_prompt"
            @value={{this.editingModel.search_prompt}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.embeddings.hints.search_prompt"}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.max_sequence_length"}}</label>
          <Input
            @type="number"
            class="ai-embedding-editor-input ai-embedding-editor__max_sequence_length"
            step="any"
            min="0"
            lang="en"
            @value={{this.editingModel.max_sequence_length}}
            required="true"
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.embeddings.hints.sequence_length"}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.embeddings.distance_function"}}</label>
          <ComboBox
            @value={{this.editingModel.pg_function}}
            @content={{this.distanceFunctions}}
            @class="ai-embedding-editor__distance_functions"
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.embeddings.hints.distance_function"}}
          />
        </div>

        {{#each-in this.metaProviderParams as |field type|}}
          <div
            class="control-group ai-embedding-editor-provider-param__{{type}}"
          >
            <label>
              {{i18n (concat "discourse_ai.embeddings.provider_fields." field)}}
            </label>
            <Input
              @type="text"
              class="ai-embedding-editor-input ai-embedding-editor__{{field}}"
              @value={{mut (get this.editingModel.provider_params field)}}
            />
          </div>
        {{/each-in}}

        <div class="control-group ai-embedding-editor__action_panel">
          <DButton
            class="ai-embedding-editor__test"
            @action={{this.test}}
            @disabled={{this.testRunning}}
            @label="discourse_ai.embeddings.tests.title"
          />

          <DButton
            class="btn-primary ai-embedding-editor__save"
            @action={{this.save}}
            @disabled={{this.isSaving}}
            @label="discourse_ai.embeddings.save"
          />
          {{#unless this.editingModel.isNew}}
            <DButton
              @action={{this.delete}}
              class="btn-danger ai-embedding-editor__delete"
              @label="discourse_ai.embeddings.delete"
            />
          {{/unless}}

          <div class="control-group ai-embedding-editor-tests">
            {{#if this.displayTestResult}}
              {{#if this.testRunning}}
                <div class="spinner small"></div>
                {{i18n "discourse_ai.embeddings.tests.running"}}
              {{else}}
                {{#if this.testResult}}
                  <div class="ai-embedding-editor-tests__success">
                    {{icon "check"}}
                    {{i18n "discourse_ai.embeddings.tests.success"}}
                  </div>
                {{else}}
                  <div class="ai-embedding-editor-tests__failure">
                    {{icon "xmark"}}
                    {{this.testErrorMessage}}
                  </div>
                {{/if}}
              {{/if}}
            {{/if}}
          </div>
        </div>
      {{/if}}
    </form>
  </template>
}
