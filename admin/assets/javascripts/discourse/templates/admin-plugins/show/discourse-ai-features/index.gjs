import Component from "@glimmer/component";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  class extends Component {
    @service adminPluginNavManager;
    @service currentUser;

    get tableHeaders() {
      const prefix = "discourse_ai.features.list.header";
      return [
        i18n(`${prefix}.name`),
        i18n(`${prefix}.persona`),
        i18n(`${prefix}.groups`),
        "",
      ];
    }

    get configuredFeatures() {
      return this.args.model.filter(
        (feature) => feature.enable_setting.value === true
      );
    }

    get unconfiguredFeatures() {
      return this.args.model.filter(
        (feature) => feature.enable_setting.value === false
      );
    }

    <template>
      <DBreadcrumbsItem
        @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-features"
        @label={{i18n "discourse_ai.features.short_title"}}
      />
      <section class="ai-feature-list admin-detail">
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.features.short_title"}}
          @descriptionLabel={{i18n "discourse_ai.features.description"}}
          @learnMoreUrl="todo"
        />

        {{#if (gt this.configuredFeatures.length 0)}}
          <div class="ai-feature-list__configured-features">
            <h3>{{i18n "discourse_ai.features.list.configured_features"}}</h3>

            <table class="d-admin-table">
              <thead>
                <tr>
                  {{#each this.tableHeaders as |header|}}
                    <th>{{header}}</th>
                  {{/each}}
                </tr>
              </thead>

              <tbody>
                {{#each this.configuredFeatures as |feature|}}
                  <tr class="ai-feature-list__row d-admin-row__content">
                    <td class="d-admin-row__overview ai-feature-list__row-item">
                      <span class="ai-feature-list__row-item-name">
                        <strong>
                          {{feature.name}}
                        </strong>
                      </span>
                      <span class="ai-feature-list__row-item-description">
                        {{feature.description}}
                      </span>
                    </td>
                    <td class="d-admin-row__detail ai-feature-list__row-item">
                      {{feature.persona.name}}
                    </td>
                    <td class="d-admin-row__detail ai-feature-list__row-item">
                      {{#if (gt feature.persona.allowed_groups.length 0)}}
                        <ul class="ai-feature-list__row-item-groups">
                          {{#each feature.persona.allowed_groups as |group|}}
                            <li>{{group.name}}</li>
                          {{/each}}
                        </ul>
                      {{/if}}
                    </td>
                    <td class="d-admin-row_controls">
                      <DButton
                        class="btn-small"
                        @translatedLabel="Edit"
                        @route="adminPlugins.show.discourse-ai-features.edit"
                        @routeModels={{feature.id}}
                      />
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>
        {{/if}}

        {{#if (gt this.unconfiguredFeatures.length 0)}}
          <div class="ai-feature-list-editor__unconfigured-features">
            <h3>{{i18n "discourse_ai.features.list.unconfigured_features"}}</h3>

            <table class="d-admin-table">
              <thead>
                <tr>
                  <th>{{i18n "discourse_ai.features.list.header.name"}}</th>
                  <th></th>
                </tr>
              </thead>

              <tbody>
                {{#each this.unconfiguredFeatures as |feature|}}
                  <tr class="ai-feature-list__row d-admin-row__content">
                    <td class="d-admin-row__overview ai-feature-list__row-item">
                      <span class="ai-feature-list__row-item-name">
                        <strong>
                          {{feature.name}}
                        </strong>
                      </span>
                      <span class="ai-feature-list__row-item-description">
                        {{feature.description}}
                      </span>
                    </td>

                    <td class="d-admin-row_controls">
                      <DButton
                        class="btn-small"
                        @label="discourse_ai.features.list.set_up"
                        @route="adminPlugins.show.discourse-ai-features.edit"
                        @routeModels={{feature.id}}
                      />
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>
        {{/if}}
      </section>
    </template>
  }
);
