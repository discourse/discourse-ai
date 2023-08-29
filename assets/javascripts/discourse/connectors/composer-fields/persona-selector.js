import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

function isBotMessage(composer, currentUser) {
  if (
    composer &&
    composer.targetRecipients &&
    currentUser.ai_enabled_chat_bots
  ) {
    let reciepients = composer.targetRecipients.split(",");

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

  get composer() {
    return this.args?.outletArgs?.model;
  }

  get botOptions() {
    if (this.currentUser.ai_enabled_personas) {
      return this.currentUser.ai_enabled_personas.map((persona) => {
        return {
          id: persona.name,
          name: persona.name,
          description: persona.description,
        };
      });
    }
  }

  get value() {
    return this._value || this.botOptions[0].id;
  }

  set value(val) {
    this._value = val;
    this.composer.metaData = { ai_persona: val };
  }
}
