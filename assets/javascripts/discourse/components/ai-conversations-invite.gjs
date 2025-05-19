import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AddPmParticipants from "discourse/components/modal/add-pm-participants";

export default class AiConversationsInvite extends Component {
  @service site;
  @service modal;

  @action
  showInvite() {
    this.modal.show(AddPmParticipants, {
      model: {
        title: "discourse_ai.ai_bot.invite_ai_conversation.title",
        inviteModel: this.args.topic,
      },
    });
  }

  <template>
    <DButton
      @icon="user-plus"
      @label="discourse_ai.ai_bot.invite_ai_conversation.button"
      @action={{this.showInvite}}
      class="ai-conversations__invite-button"
    />
  </template>
}
