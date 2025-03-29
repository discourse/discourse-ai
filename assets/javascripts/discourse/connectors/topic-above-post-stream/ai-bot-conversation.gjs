import bodyClass from "discourse/helpers/body-class";
import Component from "@glimmer/component";

export default class AiBotConversaion extends Component {
  get show() {
    return this.args.outletArgs.model?.ai_persona_name
  }

  <template>
    {{#if this.show}}
      {{bodyClass "discourse-ai-bot-conversations-page"}}
    {{/if}}
  </template>
}

