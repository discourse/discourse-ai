import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AiPersonaEditor from "./ai-persona-editor";

export default class AiPersonaListEditor extends Component {
  @service adminPluginNavManager;

  @action
  async toggleEnabled(persona) {
    const oldValue = persona.enabled;
    const newValue = !oldValue;

    try {
      persona.set("enabled", newValue);
      await persona.save();
    } catch (err) {
      persona.set("enabled", oldValue);
      popupAjaxError(err);
    }
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-personas"
      @label={{i18n "discourse_ai.ai_persona.short_title"}}
    />
    <section class="ai-persona-list-editor__current admin-detail pull-left">
      {{#if @currentPersona}}
        <AiPersonaEditor @model={{@currentPersona}} @personas={{@personas}} />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.ai_persona.short_title"}}
          @descriptionLabel={{i18n
            "discourse_ai.ai_persona.persona_description"
          }}
          @learnMoreUrl="https://meta.discourse.org/t/ai-bot-personas/306099"
        >
          <:actions as |actions|>
            <actions.Primary
              @label="discourse_ai.ai_persona.new"
              @route="adminPlugins.show.discourse-ai-personas.new"
              @icon="plus"
              class="ai-persona-list-editor__new-button"
            />
          </:actions>
        </DPageSubheader>

        {{#if @personas}}
          <table class="content-list ai-persona-list-editor d-admin-table">
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.ai_persona.name"}}</th>
                <th>{{i18n "discourse_ai.features.short_title"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @personas as |persona|}}
                {{log persona}}
                <tr
                  data-persona-id={{persona.id}}
                  class={{concatClass
                    "ai-persona-list__row d-admin-row__content"
                    (if persona.priority "--priority")
                    (if persona.enabled "--enabled")
                  }}
                >
                  <td class="d-admin-row__overview">
                    <div class="ai-persona-list__name-with-description">
                      <div class="ai-persona-list__name">
                        <strong>
                          {{persona.name}}
                          {{#if persona.enabled}}{{icon "check"}}{{/if}}
                        </strong>
                      </div>
                      <div class="ai-persona-list__description">
                        {{persona.description}}
                      </div>
                    </div>
                  </td>

                  <td class="d-admin-row__features">
                    {{#each persona.features as |feature|}}
                      {{log persona}}
                      <DButton
                        class="btn-flat btn-small ai-persona-list__row-item-feature"
                        @translatedLabel={{feature.name}}
                        @route="adminPlugins.show.discourse-ai-features.edit"
                        @routeModels={{feature.id}}
                      />
                    {{/each}}

                  </td>

                  <td class="d-admin-row__controls">
                    <LinkTo
                      @route="adminPlugins.show.discourse-ai-personas.edit"
                      @model={{persona}}
                      class="btn btn-text btn-small"
                    >{{i18n "discourse_ai.ai_persona.edit"}} </LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="discourse_ai.ai_persona.new"
            @ctaRoute="adminPlugins.show.discourse-ai-personas.new"
            @ctaClass="ai-persona-list-editor__empty-new-button"
            @emptyLabel="discourse_ai.ai_persona.no_personas"
          />
        {{/if}}
      {{/if}}
    </section>
  </template>
}
