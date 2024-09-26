import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AiLlmEditor from "./ai-llm-editor";

export default class AiLlmsListEditor extends Component {
  @service adminPluginNavManager;
  @service router;

  get hasLLMElements() {
    return this.args.llms.length !== 0;
  }

  get preConfiguredLlms() {
    let options = [
      {
        id: "none",
        name: I18n.t(`discourse_ai.llms.preconfigured.none`),
        provider: "none",
      },
    ];

    const llmsContent = this.args.llms.content.map((llm) => ({
      provider: llm.provider,
      name: llm.name,
    }));

    this.args.llms.resultSetMeta.presets.forEach((llm) => {
      if (llm.models) {
        llm.models.forEach((model) => {
          const id = `${llm.id}-${model.name}`;
          const isConfigured = llmsContent.some(
            (content) =>
              content.provider === llm.provider && content.name === model.name
          );

          // only list if it's not already configured
          if (!isConfigured) {
            options.push({
              id,
              name: model.display_name,
              provider: llm.provider,
            });
          }
        });
      }
    });

    return options;
  }

  @action
  transitionToLlmEditor(llm) {
    this.router.transitionTo("adminPlugins.show.discourse-ai-llms.new", {
      queryParams: { llmTemplate: llm },
    });
  }

  @action
  async toggleEnabledChatBot(llm) {
    const oldValue = llm.enabled_chat_bot;
    const newValue = !oldValue;
    try {
      llm.set("enabled_chat_bot", newValue);
      await llm.update({
        enabled_chat_bot: newValue,
      });
    } catch (err) {
      llm.set("enabled_chat_bot", oldValue);
      popupAjaxError(err);
    }
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-llms"
      @label={{i18n "discourse_ai.llms.short_title"}}
    />
    <section class="ai-llms-list-editor admin-detail pull-left">

      {{#if @currentLlm}}
        <AiLlmEditor
          @model={{@currentLlm}}
          @llms={{@llms}}
          @llmTemplate={{@llmTemplate}}
        />
      {{else}}
        {{#if this.hasLLMElements}}
          <h3>
            {{i18n "discourse_ai.llms.configured.title"}}
          </h3>
          <table class="content-list ai-persona-list-editor">
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.llms.display_name"}}</th>
                <th>{{i18n "discourse_ai.llms.provider"}}</th>
                <th>{{i18n "discourse_ai.llms.enabled_chat_bot"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @llms as |llm|}}
                <tr data-persona-id={{llm.id}} class="ai-llm-list__row">
                  <td><strong>{{llm.display_name}}</strong></td>
                  <td>{{i18n
                      (concat "discourse_ai.llms.providers." llm.provider)
                    }}</td>
                  <td>
                    <DToggleSwitch
                      @state={{llm.enabled_chat_bot}}
                      {{on "click" (fn this.toggleEnabledChatBot llm)}}
                    />
                  </td>
                  <td>
                    <LinkTo
                      @route="adminPlugins.show.discourse-ai-llms.show"
                      current-when="true"
                      class="btn btn-text btn-small"
                      @model={{llm}}
                    >{{i18n "discourse_ai.llms.edit"}}</LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}

        <h3>
          {{#if this.hasLLMElements}}
            {{i18n "discourse_ai.llms.preconfigured.title"}}
          {{else}}
            {{i18n "discourse_ai.llms.preconfigured.title_no_llms"}}
          {{/if}}
        </h3>
        <table class="content-list ai-persona-list-editor">
          <thead>
            <tr>
              <th>{{i18n "discourse_ai.llms.display_name"}}</th>
              <th>{{i18n "discourse_ai.llms.provider"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.preConfiguredLlms as |llm|}}
              <tr data-persona-id={{llm.id}} class="ai-llm-list__row">
                <td>{{llm.name}}</td>
                <td>{{i18n
                    (concat "discourse_ai.llms.providers." llm.provider)
                  }}</td>
                <td>
                  <DButton
                    @action={{fn this.transitionToLlmEditor llm.id}}
                    @icon="plus"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </section>
  </template>
}
