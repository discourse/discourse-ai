import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DebugAiModal from "../modal/debug-ai-modal";

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
  static debugAiResponse(post, modal) {
    modal.show(DebugAiModal, { model: post });
  }

  @service modal;

  @action
  debugAiResponse() {
    this.constructor.debugAiResponse(this.args.post, this.modal);
  }

  <template>
    <DButton
      class="post-action-menu__debug-ai"
      ...attributes
      @action={{this.debugAiResponse}}
      @icon="info"
      @title="discourse_ai.ai_bot.debug_ai"
    />
  </template>
}
