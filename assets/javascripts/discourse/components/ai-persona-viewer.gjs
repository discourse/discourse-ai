import Component from '@glimmer/component';
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from '@ember/routing';
import DToggleSwitch from "discourse/components/d-toggle-switch";

export default class AiPersonaViewer extends Component {
  constructor() {
    super(...arguments);
    this.aiPersona = this.args.model;
  }

  @action
  toggleEnabled() {
    this.aiPersona.set("enabled", !this.aiPersona.enabled);
    this.aiPersona.save();
  }

  <template>
    <div class="persona-viewer">
      <div class="persona-viewer__content">
        <h3 class="persona-viewer__name">{{this.aiPersona.name}}</h3>
        <DToggleSwitch
          class="persona-viewer__enabled"
          @state={{this.aiPersona.enabled}}
          @label="discourse_ai.ai-persona.enabled"
          {{on "click" this.toggleEnabled}}
        />
        <p class="persona-viewer__description">{{this.aiPersona.description}}</p>
        <LinkTo
          @route="adminPlugins.discourse-ai.ai-personas.show"
          @model={{this.aiPersona}}
        >edit</LinkTo>
      </div>
    </div>
  </template>
}
