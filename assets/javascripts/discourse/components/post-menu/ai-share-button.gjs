import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import copyConversation from "../../lib/copy-conversation";
import ShareModal from "../modal/share-modal";

const AUTO_COPY_THRESHOLD = 4;
const MAX_PERSONA_USER_ID = -1200;

export default class AiDebugButton extends Component {
  static shouldRender(args) {
    if (
      !args.state.currentUser.ai_enabled_chat_bots.any(
        (bot) => args.post.username === bot.username
      )
    ) {
      // special handling for personas (persona bot users start at ID -1200 and go down)
      if (args.post.user_id > MAX_PERSONA_USER_ID) {
        return false;
      }
    }

    return true;
  }

  // TODO (glimmer-post-menu): Remove this static function and move the code into the button action after the widget code is removed
  static async shareAiResponse(post, modal, showFeedback) {
    if (post.post_number <= AUTO_COPY_THRESHOLD) {
      await copyConversation(post.topic, 1, post.post_number);
      showFeedback("discourse_ai.ai_bot.conversation_shared");
    } else {
      modal.show(ShareModal, { model: post });
    }
  }

  @service modal;

  @action
  shareAiResponse() {
    this.constructor.shareAiResponse(
      this.args.post,
      this.modal,
      this.args.showFeedback
    );
  }

  <template>
    <DButton
      class="post-action-menu__share-ai"
      ...attributes
      @action={{this.shareAiResponse}}
      @icon="far-copy"
      @title="discourse_ai.ai_bot.share"
    />
  </template>
}
