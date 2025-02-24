import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import DMenu from "float-kit/components/d-menu";

export default class AiToolListEditor extends Component {
  @service adminPluginNavManager;
  @service router;

  get lastIndexOfPresets() {
    return this.args.tools.resultSetMeta.presets.length - 1;
  }

  @action
  routeToNewTool(preset) {
    return this.router.transitionTo(
      "adminPlugins.show.discourse-ai-tools.new",
      {
        queryParams: {
          presetId: preset.preset_id,
        },
      }
    );
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-tools"
      @label={{i18n "discourse_ai.tools.short_title"}}
    />
    <section class="ai-tool-list-editor__current admin-detail pull-left">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.tools.short_title"}}
        @learnMoreUrl="https://meta.discourse.org/t/ai-bot-custom-tools/314103"
        @descriptionLabel={{i18n "discourse_ai.tools.subheader_description"}}
      >
        <:actions>
          <DMenu
            @triggerClass="btn-primary btn-small"
            @label={{i18n "discourse_ai.tools.new"}}
            @icon="plus"
            @placement="bottom-end"
          >
            <:content>
              <DropdownMenu as |dropdown|>
                {{#each @tools.resultSetMeta.presets as |preset index|}}
                  {{#if (eq index this.lastIndexOfPresets)}}
                    <dropdown.divider />
                  {{/if}}

                  <dropdown.item>
                    <DButton
                      @translatedLabel={{preset.preset_name}}
                      @action={{fn this.routeToNewTool preset}}
                      class="btn-transparent"
                    />
                  </dropdown.item>
                {{/each}}
              </DropdownMenu>

            </:content>
          </DMenu>
        </:actions>
      </DPageSubheader>

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
                    @route="adminPlugins.show.discourse-ai-tools.edit"
                    @model={{tool}}
                    class="btn btn-text btn-small"
                  >{{i18n "discourse_ai.tools.edit"}}</LinkTo>
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
