import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopyAsync } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class ShareModal extends Component {
  @service toasts;
  @tracked shareKey = "";

  constructor() {
    super(...arguments);
    this.shareKey = this.args.model.share_key;
  }

  get htmlContext() {
    let context = [];

    this.args.model.context.forEach((post) => {
      context.push(`<p><b>${post.username}:</b></p>`);
      context.push(post.cooked);
    });
    return htmlSafe(context.join("\n"));
  }

  async generateShareURL() {
    try {
      const response = await ajax(
        "/discourse-ai/ai-bot/shared-ai-conversations",
        {
          type: "POST",
          data: {
            topic_id: this.args.model.topic_id,
          },
        }
      );

      const url = getAbsoluteURL(
        `/discourse-ai/ai-bot/shared-ai-conversations/${response.share_key}`
      );
      this.shareKey = response.share_key;

      return new Blob([url], { type: "text/plain" });
    } catch (e) {
      popupAjaxError(e);
      return;
    }
  }

  get primaryLabel() {
    return this.shareKey
      ? "discourse_ai.ai_bot.share_full_topic_modal.update"
      : "discourse_ai.ai_bot.share_full_topic_modal.share";
  }

  @action
  async deleteLink() {
    try {
      await ajax(
        `/discourse-ai/ai-bot/shared-ai-conversations/${this.shareKey}.json`,
        {
          type: "DELETE",
        }
      );

      this.shareKey = null;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async share() {
    await clipboardCopyAsync(this.generateShareURL.bind(this));
    this.toasts.success({
      duration: 3000,
      data: {
        message: I18n.t("discourse_ai.ai_bot.conversation_shared"),
      },
    });
  }

  <template>
    <DModal
      class="ai-share-full-topic-modal"
      @title={{i18n "discourse_ai.ai_bot.share_full_topic_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="ai-share-full-topic-modal__body">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary confirm"
          @icon="copy"
          @action={{this.share}}
          @label={{this.primaryLabel}}
        />
        {{#if this.shareKey}}
          <DButton
            class="btn-danger"
            @icon="far-trash-alt"
            @action={{this.deleteLink}}
            @label="discourse_ai.ai_bot.share_full_topic_modal.delete"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
