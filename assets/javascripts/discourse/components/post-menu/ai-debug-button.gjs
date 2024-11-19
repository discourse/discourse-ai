import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isPostFromAiBot } from "../../lib/ai-bot-helper";
import DebugAiModal from "../modal/debug-ai-modal";

export default class AiDebugButton extends Component {
  static shouldRender(args) {
    return isPostFromAiBot(args.post, args.state.currentUser);
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
