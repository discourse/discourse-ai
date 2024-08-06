import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Avatar from "discourse/helpers/bound-avatar-template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import ComboBox from "select-kit/components/combo-box";
import DTooltip from "float-kit/components/d-tooltip";

export default class AiLlmEditorForm extends Component {
  @service toasts;
  @service router;
  @service dialog;

  @tracked isSaving = false;

  @tracked testRunning = false;
  @tracked testResult = null;
  @tracked testError = null;
  @tracked apiKeySecret = true;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (!this.args.model.provider_params) {
      this.populateProviderParams(this.args.model.provider);
    }
  }

  get selectedProviders() {
    const t = (provName) => {
      return I18n.t(`discourse_ai.llms.providers.${provName}`);
    };

    return this.args.llms.resultSetMeta.providers.map((prov) => {
      return { id: prov, name: t(prov) };
    });
  }

  get adminUser() {
    return AdminUser.create(this.args.model?.user);
  }

  get testErrorMessage() {
    return I18n.t("discourse_ai.llms.tests.failure", { error: this.testError });
  }

  get displayTestResult() {
    return this.testRunning || this.testResult !== null;
  }

  get canEditURL() {
    // Explicitly false.
    return this.metaProviderParams.url_editable !== false;
  }

  get modulesUsingModel() {
    return this.args.model.used_by?.join(", ");
  }

  get inUseWarning() {
    return I18n.t("discourse_ai.llms.in_use_warning", {
      settings: this.modulesUsingModel,
      count: this.args.model.used_by.length,
    });
  }

  @computed("args.model.provider")
  get metaProviderParams() {
    return (
      this.args.llms.resultSetMeta.provider_params[this.args.model.provider] ||
      {}
    );
  }

  @action
  async save() {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    try {
      const result = await this.args.model.save();

      this.args.model.setProperties(result.responseJson.ai_persona);

      if (isNew) {
        this.args.llms.addObject(this.args.model);
        this.router.transitionTo("adminPlugins.show.discourse-ai-llms.index");
      } else {
        this.toasts.success({
          data: { message: I18n.t("discourse_ai.llms.saved") },
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
      const configTestResult = await this.args.model.testConfig();
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
  makeApiKeySecret() {
    this.apiKeySecret = true;
  }

  @action
  toggleApiKeySecret() {
    this.apiKeySecret = !this.apiKeySecret;
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.llms.confirm_delete"),
      didConfirm: () => {
        return this.args.model
          .destroyRecord()
          .then(() => {
            this.args.llms.removeObject(this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-llms.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  async toggleEnabledChatBot() {
    this.args.model.set("enabled_chat_bot", !this.args.model.enabled_chat_bot);
    if (!this.args.model.isNew) {
      try {
        await this.args.model.update({
          enabled_chat_bot: this.args.model.enabled_chat_bot,
        });
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  <template>
    {{#if this.modulesUsingModel}}
      <div class="alert alert-info">
        {{icon "exclamation-circle"}}
        {{this.inUseWarning}}
      </div>
    {{/if}}
    <form class="form-horizontal ai-llm-editor">
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.display_name"}}</label>
        <Input
          class="ai-llm-editor-input ai-llm-editor__display-name"
          @type="text"
          @value={{@model.display_name}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.name"}}</label>
        <Input
          class="ai-llm-editor-input ai-llm-editor__name"
          @type="text"
          @value={{@model.name}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.llms.hints.name"}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.llms.provider"}}</label>
        <ComboBox
          @value={{@model.provider}}
          @content={{this.selectedProviders}}
        />
      </div>
      {{#if this.canEditURL}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.llms.url"}}</label>
          <Input
            class="ai-llm-editor-input ai-llm-editor__url"
            @type="text"
            @value={{@model.url}}
            required="true"
          />
        </div>
      {{/if}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.llms.api_key"}}</label>
        <div class="ai-llm-editor__secret-api-key-group">
          <Input
            @value={{@model.api_key}}
            class="ai-llm-editor-input ai-llm-editor__api-key"
            @type={{if this.apiKeySecret "password" "text"}}
            required="true"
            {{on "focusout" this.makeApiKeySecret}}
          />
          <DButton @action={{this.toggleApiKeySecret}} @icon="far-eye-slash" />
        </div>
      </div>
      {{#each this.metaProviderParams.fields as |field|}}
        <div class="control-group">
          <label>{{I18n.t
              (concat "discourse_ai.llms.provider_fields." field)
            }}</label>
          <Input
            @type="text"
            @value={{mut (get @model.provider_params field)}}
            class="ai-llm-editor-input ai-llm-editor__{{field}}"
          />
        </div>
      {{/each}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.llms.tokenizer"}}</label>
        <ComboBox
          @value={{@model.tokenizer}}
          @content={{@llms.resultSetMeta.tokenizers}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.max_prompt_tokens"}}</label>
        <Input
          @type="number"
          class="ai-llm-editor-input ai-llm-editor__max-prompt-tokens"
          step="any"
          min="0"
          lang="en"
          @value={{@model.max_prompt_tokens}}
          required="true"
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.llms.hints.max_prompt_tokens"}}
        />
      </div>
      <div class="control-group ai-llm-editor__vision-enabled">
        <Input @type="checkbox" @checked={{@model.vision_enabled}} />
        <label>{{I18n.t "discourse_ai.llms.vision_enabled"}}</label>
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.llms.hints.vision_enabled"}}
        />
      </div>
      <div class="control-group">
        <DToggleSwitch
          class="ai-llm-editor__enabled-chat-bot"
          @state={{@model.enabled_chat_bot}}
          @label="discourse_ai.llms.enabled_chat_bot"
          {{on "click" this.toggleEnabledChatBot}}
        />
      </div>
      {{#if @model.user}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.llms.ai_bot_user"}}</label>
          <a
            class="avatar"
            href={{@model.user.path}}
            data-user-card={{@model.user.username}}
          >
            {{Avatar @model.user.avatar_template "small"}}
          </a>
          <LinkTo @route="adminUser" @model={{this.adminUser}}>
            {{@model.user.username}}
          </LinkTo>
        </div>
      {{/if}}
      <div class="control-group ai-llm-editor__action_panel">
        <DButton
          class="ai-llm-editor__test"
          @action={{this.test}}
          @disabled={{this.testRunning}}
        >
          {{I18n.t "discourse_ai.llms.tests.title"}}
        </DButton>

        <DButton
          class="btn-primary ai-llm-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >
          {{I18n.t "discourse_ai.llms.save"}}
        </DButton>
        {{#unless @model.isNew}}
          <DButton
            @action={{this.delete}}
            class="btn-danger ai-llm-editor__delete"
          >
            {{I18n.t "discourse_ai.llms.delete"}}
          </DButton>
        {{/unless}}
      </div>

      <div class="control-group ai-llm-editor-tests">
        {{#if this.displayTestResult}}
          {{#if this.testRunning}}
            <div class="spinner small"></div>
            {{I18n.t "discourse_ai.llms.tests.running"}}
          {{else}}
            {{#if this.testResult}}
              <div class="ai-llm-editor-tests__success">
                {{icon "check"}}
                {{I18n.t "discourse_ai.llms.tests.success"}}
              </div>
            {{else}}
              <div class="ai-llm-editor-tests__failure">
                {{icon "times"}}
                {{this.testErrorMessage}}
              </div>
            {{/if}}
          {{/if}}
        {{/if}}
      </div>
    </form>
  </template>
}
