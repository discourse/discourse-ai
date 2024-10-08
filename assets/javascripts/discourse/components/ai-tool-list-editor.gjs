import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

export default class AiToolListEditor extends Component {
  @service adminPluginNavManager;

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-tools"
      @label={{i18n "discourse_ai.tools.short_title"}}
    />
    <section class="ai-tool-list-editor__current admin-detail pull-left">
      <div class="ai-tool-list-editor__header">
        <h3>{{I18n.t "discourse_ai.tools.short_title"}}</h3>
        <LinkTo
          @route="adminPlugins.show.discourse-ai-tools.new"
          class="btn btn-small btn-primary ai-tool-list-editor__new-button"
        >
          {{icon "plus"}}
          <span>{{I18n.t "discourse_ai.tools.new"}}</span>
        </LinkTo>
      </div>

      <table class="content-list ai-tool-list-editor">
        <tbody>
          {{#each @tools as |tool|}}
            <tr data-tool-id={{tool.id}} class="ai-tool-list__row">
              <td>
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
              <td>
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
    </section>
  </template>
}
