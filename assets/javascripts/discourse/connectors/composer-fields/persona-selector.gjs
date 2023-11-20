import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { inject as service } from "@ember/service";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

function isBotMessage(composer, currentUser) {
  if (
    composer &&
    composer.targetRecipients &&
    currentUser.ai_enabled_chat_bots
  ) {
    const reciepients = composer.targetRecipients.split(",");

    return currentUser.ai_enabled_chat_bots.any((bot) =>
      reciepients.any((username) => username === bot.username)
    );
  }
  return false;
}

export default class BotSelector extends Component {
  static shouldRender(args, container) {
    return (
      container?.currentUser?.ai_enabled_personas &&
      isBotMessage(args.model, container.currentUser)
    );
  }

  @service currentUser;
  constructor() {
    super(...arguments);
    if (this.botOptions && this.composer) {
      this._value = this.botOptions[0].id;
      this.composer.metaData = { ai_persona_id: this._value };
    }
  }

  get composer() {
    return this.args?.outletArgs?.model;
  }

  get botOptions() {
    if (this.currentUser.ai_enabled_personas) {
      return this.currentUser.ai_enabled_personas.map((persona) => {
        return {
          id: persona.id,
          name: persona.name,
          description: persona.description,
        };
      });
    }
  }

  get value() {
    return this._value;
  }

  set value(val) {
    this._value = val;
    this.composer.metaData = { ai_persona_id: val };
  }

  <template>
    <div class="gpt-persona">
      <DropdownSelectBox
        @value={{this.value}}
        @content={{this.botOptions}}
        @options={{hash icon="robot"}}
      />
    </div>
  </template>
}
