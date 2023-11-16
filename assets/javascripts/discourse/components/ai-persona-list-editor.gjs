import Component from '@glimmer/component';
import { tracked } from "@glimmer/tracking";
import { LinkTo } from '@ember/routing';
import { htmlSafe } from '@ember/template';
import { cook } from "discourse/lib/text";
import { renderIcon } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";
import AiPersonaEditor from "./ai-persona-editor";

export default class AiPersonaListEditor extends Component {

  @tracked _noPersonaText = null;

  constructor() {
    super(...arguments);
  }

  get noPersonaText() {
    if (this._noPersonaText === null) {
      const raw = I18n.t("discourse_ai.ai-persona.no_persona_selected");
      cook(raw).then((result) => {
        this._noPersonaText = result;
      });
    }
    return this._noPersonaText;
  }

  get plusIcon() {
    return htmlSafe(renderIcon("string", "plus"));
  }

  <template>
    <div class="ai-persona-list-editor__header">
      <h3>{{I18n.t "discourse_ai.ai-persona.title"}}</h3>
      <LinkTo @route="adminPlugins.discourse-ai.ai-personas.new" class="btn btn-primary">
        {{this.plusIcon}}
        <span>{{I18n.t "discourse_ai.ai-persona.new"}}</span>
      </LinkTo>
    </div>
    <div class="content-list ai-persona-list-editor">
      <ul>
        {{#each this.args.personas as |persona|}}
          <li>
            <LinkTo @route="adminPlugins.discourse-ai.ai-personas.show"
              current-when=true
              @model={{persona}}>{{persona.name}}
            </LinkTo>
          </li>
        {{/each}}
      </ul>
    </div>
    <section class="ai-persona-list-editor__current content-body">
      {{#if this.args.currentPersona}}
        <AiPersonaEditor @model={{this.args.currentPersona}} />
      {{else}}
        <div class="ai-persona-list-editor__empty">
          {{this.noPersonaText}}
        </div>
      {{/if}}
    </section>
  </template>
}
