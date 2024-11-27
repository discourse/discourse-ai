import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AdminPageSubheader from "admin/components/admin-page-subheader";

export default class AiToolListEditor extends Component {
  @service adminPluginNavManager;

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-tools"
      @label={{i18n "discourse_ai.tools.short_title"}}
    />
    <section class="ai-tool-list-editor__current admin-detail pull-left">
      <AdminPageSubheader
        @titleLabel="discourse_ai.tools.short_title"
        @learnMoreUrl="https://meta.discourse.org/t/ai-bot-custom-tools/314103"
        @descriptionLabel="discourse_ai.tools.subheader_description"
      >
        <:actions as |actions|>
          <actions.Primary
            @label="discourse_ai.tools.new"
            @route="adminPlugins.show.discourse-ai-tools.new"
            @icon="plus"
            class="ai-tool-list-editor__new-button"
          />
        </:actions>
      </AdminPageSubheader>

      {{#if @tools}}
        <table class="d-admin-table ai-tool-list-editor">
          <thead>
            <th>{{i18n "discourse_ai.tools.name"}}</th>
            <th></th>
          </thead>
          <tbody>
            {{#each @tools as |tool|}}
              <tr
                data-tool-id={{tool.id}}
                class="ai-tool-list__row d-admin-row__content"
              >
                <td class="d-admin-row__overview">
                  <div class="ai-tool-list__name-with-description">
                    <div class="ai-tool-list__name">
                      <strong>
                        {{tool.name}}
                      </strong>
                    </div>
                    <div class="ai-tool-list__description">
                      {{tool.description}}
                    </div>
                  </div>
                </td>
                <td class="d-admin-row__controls">
                  <LinkTo
                    @route="adminPlugins.show.discourse-ai-tools.show"
                    @model={{tool}}
                    class="btn btn-text btn-small"
                  >{{I18n.t "discourse_ai.tools.edit"}}</LinkTo>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="discourse_ai.tools.new"
          @ctaRoute="adminPlugins.show.discourse-ai-tools.new"
          @ctaClass="ai-tool-list-editor__empty-new-button"
          @emptyLabel="discourse_ai.tools.no_tools"
        />
      {{/if}}
    </section>
  </template>
}
