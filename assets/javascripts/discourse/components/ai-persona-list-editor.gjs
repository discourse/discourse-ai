import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
import { cook } from "discourse/lib/text";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import AiPersonaEditor from "./ai-persona-editor";

export default class AiPersonaListEditor extends Component {
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

  <template>
    <div class="ai-persona-list-editor__header">
      <h3></h3>
      {{#unless @currentPersona.isNew}}
        <LinkTo
          @route="adminPlugins.show.discourse-ai.ai-personas.new"
          class="btn btn-primary"
        >
          {{icon "plus"}}
          <span>{{I18n.t "discourse_ai.ai_persona.new"}}</span>
        </LinkTo>
      {{/unless}}
    </div>
    <section class="ai-persona-list-editor__current content-body">
      {{#if @currentPersona}}
        <AiPersonaEditor @model={{@currentPersona}} @personas={{@personas}} />
      {{else}}
        <div class="ai-persona-list-editor__empty">
          {{this.noPersonaText}}
        </div>

        <div class="content-list ai-persona-list-editor">
          <ul>
            {{#each @personas as |persona|}}
              <li
                class={{concatClass
                  (if persona.enabled "" "diabled")
                  (if persona.priority "priority")
                }}
              >
                <LinkTo
                  @route="adminPlugins.show.discourse-ai.ai-personas.show"
                  current-when="true"
                  @model={{persona}}
                >{{persona.name}}
                </LinkTo>
              </li>
            {{/each}}
          </ul>
        </div>
      {{/if}}
    </section>
  </template>
}
