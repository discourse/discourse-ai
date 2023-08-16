import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { computed } from "@ember/object";

export default class extends Component {
  static shouldRender() {
    return true;
  }

  @service currentUser;
  @service siteSettings;

  get composerModel() {
    return this.args.outletArgs.model;
  }

  get renderChatWarning() {
    return this.siteSettings.ai_bot_enable_chat_warning;
  }

  @computed("composerModel.targetRecipients")
  get isGptChat() {
    if (this.composerModel.targetRecipients) {
      let reciepients = this.composerModel.targetRecipients.split(",");

      return this.currentUser.ai_enabled_chat_bots.any((bot) =>
        reciepients.any((username) => username === bot.username)
      );
    }
    return false;
  }
}
