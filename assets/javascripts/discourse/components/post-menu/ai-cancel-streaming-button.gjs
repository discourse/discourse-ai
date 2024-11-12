import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AiCancelStreamingButton extends Component {
  // TODO (glimmer-post-menu): Remove this static function and move the code into the button action after the widget code is removed
  static async cancelStreaming(post) {
    try {
      await ajax(`/discourse-ai/ai-bot/post/${post.id}/stop-streaming`, {
        type: "POST",
      });

      document
        .querySelector(`#post_${post.post_number}`)
        .classList.remove("streaming");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  cancelStreaming() {
    this.constructor.cancelStreaming(this.args.post);
  }

  <template>
    <DButton
      class="post-action-menu__ai-cancel-streaming cancel-streaming"
      ...attributes
      @action={{this.cancelStreaming}}
      @icon="pause"
      @title="discourse_ai.ai_bot.cancel_streaming"
    />
  </template>
}
