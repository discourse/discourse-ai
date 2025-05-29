import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AiAgentEditor from "./ai-agent-editor";

export default class AiAgentListEditor extends Component {
  @service adminPluginNavManager;

  @action
  async toggleEnabled(agent) {
    const oldValue = agent.enabled;
    const newValue = !oldValue;

    try {
      agent.set("enabled", newValue);
      await agent.save();
    } catch (err) {
      agent.set("enabled", oldValue);
      popupAjaxError(err);
    }
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-agents"
      @label={{i18n "discourse_ai.ai_agent.short_title"}}
    />
    <section class="ai-agent-list-editor__current admin-detail pull-left">
      {{#if @currentAgent}}
        <AiAgentEditor @model={{@currentAgent}} @agents={{@agents}} />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.ai_agent.short_title"}}
          @descriptionLabel={{i18n
            "discourse_ai.ai_agent.agent_description"
          }}
          @learnMoreUrl="https://meta.discourse.org/t/ai-bot-agents/306099"
        >
          <:actions as |actions|>
            <actions.Primary
              @label="discourse_ai.ai_agent.new"
              @route="adminPlugins.show.discourse-ai-agents.new"
              @icon="plus"
              class="ai-agent-list-editor__new-button"
            />
          </:actions>
        </DPageSubheader>

        {{#if @agents}}
          <table class="content-list ai-agent-list-editor d-admin-table">
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.ai_agent.name"}}</th>
                <th>{{i18n "discourse_ai.ai_agent.list.enabled"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @agents as |agent|}}
                <tr
                  data-agent-id={{agent.id}}
                  class={{concatClass
                    "ai-agent-list__row d-admin-row__content"
                    (if agent.priority "priority")
                  }}
                >
                  <td class="d-admin-row__overview">
                    <div class="ai-agent-list__name-with-description">
                      <div class="ai-agent-list__name">
                        <strong>
                          {{agent.name}}
                        </strong>
                      </div>
                      <div class="ai-agent-list__description">
                        {{agent.description}}
                      </div>
                    </div>
                  </td>
                  <td class="d-admin-row__detail">
                    <DToggleSwitch
                      @state={{agent.enabled}}
                      {{on "click" (fn this.toggleEnabled agent)}}
                    />
                  </td>
                  <td class="d-admin-row__controls">
                    <LinkTo
                      @route="adminPlugins.show.discourse-ai-agents.edit"
                      @model={{agent}}
                      class="btn btn-text btn-small"
                    >{{i18n "discourse_ai.ai_agent.edit"}} </LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="discourse_ai.ai_agent.new"
            @ctaRoute="adminPlugins.show.discourse-ai-agents.new"
            @ctaClass="ai-agent-list-editor__empty-new-button"
            @emptyLabel="discourse_ai.ai_agent.no_agents"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
