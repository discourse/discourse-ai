import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AiLlmEditor from "./ai-llm-editor";

export default class AiLlmsListEditor extends Component {
  get hasLLMElements() {
    return this.args.llms.length !== 0;
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
    <section class="ai-llms-list-editor admin-detail pull-left">
      {{#if @currentLlm}}
        <AiLlmEditor @model={{@currentLlm}} @llms={{@llms}} />
      {{else}}
        <div class="ai-llms-list-editor__header">
          <h3>{{i18n "discourse_ai.llms.short_title"}}</h3>
          {{#unless @currentLlm.isNew}}
            <LinkTo
              @route="adminPlugins.show.discourse-ai-llms.new"
              class="btn btn-small btn-primary ai-llms-list-editor__new"
            >
              {{icon "plus"}}
              <span>{{I18n.t "discourse_ai.llms.new"}}</span>
            </LinkTo>
          {{/unless}}
        </div>

        {{#if this.hasLLMElements}}
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
      {{/if}}
    </section>
  </template>
}
