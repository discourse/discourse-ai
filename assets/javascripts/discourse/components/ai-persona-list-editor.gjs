import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AiPersonaEditor from "./ai-persona-editor";

export default class AiPersonaListEditor extends Component {
  @service adminPluginNavManager;
  @tracked _noPersonaText = null;

  get noPersonaText() {
    if (this._noPersonaText === null) {
      const raw = I18n.t("discourse_ai.ai_persona.no_persona_selected");
      cook(raw).then((result) => {
        this._noPersonaText = result;
      });
    }

    return this._noPersonaText;
  }

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
        <div class="ai-persona-list-editor__header">
          <h3>{{i18n "discourse_ai.ai_persona.short_title"}}</h3>
          {{#unless @currentPersona.isNew}}
            <LinkTo
              @route="adminPlugins.show.discourse-ai-personas.new"
              class="btn btn-small btn-primary"
            >
              {{icon "plus"}}
              <span>{{I18n.t "discourse_ai.ai_persona.new"}}</span>
            </LinkTo>
          {{/unless}}
        </div>

        <div class="ai-persona-list-editor__empty">
          <details class="details__boxed">
            <summary>{{i18n
                "discourse_ai.ai_persona.what_are_personas"
              }}</summary>
            {{this.noPersonaText}}
          </details>
        </div>

        <table class="content-list ai-persona-list-editor">
          <thead>
            <tr>
              <th>{{i18n "discourse_ai.ai_persona.name"}}</th>
              <th>{{i18n "discourse_ai.ai_persona.enabled"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @personas as |persona|}}
              <tr
                data-persona-id={{persona.id}}
                class={{concatClass
                  "ai-persona-list__row"
                  (if persona.priority "priority")
                }}
              >
                <td>
                  <div class="ai-persona-list__name-with-description">
                    <div class="ai-persona-list__name">
                      <strong>
                        {{persona.name}}
                      </strong>
                    </div>
                    <div class="ai-persona-list__description">
                      {{persona.description}}
                    </div>
                  </div>
                </td>
                <td>
                  <DToggleSwitch
                    @state={{persona.enabled}}
                    {{on "click" (fn this.toggleEnabled persona)}}
                  />
                </td>
                <td>
                  <LinkTo
                    @route="adminPlugins.show.discourse-ai-personas.show"
                    @model={{persona}}
                    class="btn btn-text btn-small"
                  >{{i18n "discourse_ai.ai_persona.edit"}} </LinkTo>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </section>
  </template>
}
