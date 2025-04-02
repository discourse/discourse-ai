import Component from "@glimmer/component";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  class extends Component {
    @service adminPluginNavManager;

    <template>
      <DBreadcrumbsItem
        @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-features"
        @label={{i18n "discourse_ai.features.short_title"}}
      />
      <section class="ai-feature-list-editor admin-detail">
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.features.short_title"}}
          @descriptionLabel={{i18n "discourse_ai.features.description"}}
          @learnMoreUrl="todo"
        />

        <div class="ai-feature-list-editor__configured-features">
          <h3>Configured Features</h3>
          <table class="d-admin-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Persona</th>
                <th>Groups</th>
                <th></th>
              </tr>
            </thead>

            <tbody>
              {{#each @model as |feature|}}
                {{!-- {{log feature}} --}}
                <tr class="ai-features-list__row d-admin-row__content">
                  <td class="d-admin-row__overview">
                    <strong>{{feature.name}}</strong><br />
                    {{feature.description}}
                  </td>
                  <td class="d-admin-row__detail">
                    {{feature.persona}}
                  </td>
                  <td></td>
                  <td class="d-admin-row_controls">
                    <DButton @translatedLabel="Edit" />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>

        {{! <div class="ai-feature-list-editor__unconfigured-features">
          <h3>Unconfigured Features</h3>
        </div> }}
      </section>
    </template>
  }
);
