import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { or } from "truth-helpers";
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

  sanitizedTranslationKey(id) {
    return id.replace(/\./g, "-");
  }

  get hasLLMElements() {
    return this.args.llms.length !== 0;
  }

  get preConfiguredLlms() {
    let options = [
      {
        id: "none",
        name: I18n.t(`discourse_ai.llms.preconfigured.fake`),
        provider: "fake",
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
    <section class="ai-llm-list-editor admin-detail">
      {{#if @currentLlm}}
        <AiLlmEditor
          @model={{@currentLlm}}
          @llms={{@llms}}
          @llmTemplate={{@llmTemplate}}
        />
      {{else}}
        {{#if this.hasLLMElements}}
          <section class="ai-llms-list-editor__configured">
            <div class="admin-page-subheader">
              <div class="admin-page-subheader__title-row">
                <h2 class="admin-page-subheader__title">
                  {{i18n "discourse_ai.llms.configured.title"}}
                </h2>
              </div>
            </div>
            <table>
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
                    <td class="column-name">
                      <h3>{{llm.display_name}}</h3>
                      <p>
                        {{i18n
                          (concat
                            "discourse_ai.llms.model_description."
                            llm.provider
                            "-"
                            llm.name
                          )
                        }}
                      </p>
                    </td>
                    <td>
                      {{i18n
                        (concat "discourse_ai.llms.providers." llm.provider)
                      }}
                    </td>
                    <td>
                      <DToggleSwitch
                        @state={{llm.enabled_chat_bot}}
                        {{on "click" (fn this.toggleEnabledChatBot llm)}}
                      />
                    </td>
                    <td class="column-edit">
                      <LinkTo
                        @route="adminPlugins.show.discourse-ai-llms.show"
                        class="btn btn-default"
                        @model={{or llm.id llm.llm.id}}
                      >
                        {{icon "wrench"}}
                        <div class="d-button-label">
                          {{i18n "discourse_ai.llms.edit"}}
                        </div>
                      </LinkTo>
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </section>
        {{/if}}
        <section class="ai-llms-list-editor__templates">
          <div class="admin-page-subheader">
            <div class="admin-page-subheader__title-row">
              <h2 class="admin-page-subheader__title">
                {{#if this.hasLLMElements}}
                  {{i18n "discourse_ai.llms.preconfigured.title"}}
                {{else}}
                  {{i18n "discourse_ai.llms.preconfigured.title_no_llms"}}
                {{/if}}
              </h2>
            </div>
          </div>
          <div class="ai-llms-list-editor__templates-list">
            {{#each this.preConfiguredLlms as |llm|}}
              <div
                data-llm-id={{llm.id}}
                class="ai-llms-list-editor__templates-list-item"
              >
                <h4>
                  {{i18n (concat "discourse_ai.llms.providers." llm.provider)}}
                </h4>
                <h3>
                  {{llm.name}}
                </h3>
                <p>
                  {{i18n
                    (concat
                      "discourse_ai.llms.model_description."
                      (this.sanitizedTranslationKey llm.id)
                    )
                  }}
                </p>
                <DButton
                  @action={{fn this.transitionToLlmEditor llm.id}}
                  @icon="gear"
                  @label="discourse_ai.llms.preconfigured.button"
                />
              </div>
            {{/each}}
          </div>
        </section>
      {{/if}}
    </section>
  </template>
}
