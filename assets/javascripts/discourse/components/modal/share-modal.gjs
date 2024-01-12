import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";
import copyConversation from "../../lib/copy-conversation";

export default class ShareModal extends Component {
  @tracked contextValue = 1;
  @tracked htmlContext = "";
  @tracked maxContext = 0;
  @tracked allPosts = [];
  @tracked justCopiedText = "";

  constructor() {
    super(...arguments);

    const postStream = this.args.model.topic.get("postStream");

    let postNumbers = [];
    // simpler to understand than Array.from
    for (let i = 1; i <= this.args.model.post_number; i++) {
      postNumbers.push(i);
    }

    this.allPosts = postNumbers
      .map((postNumber) => {
        let postId = postStream.findPostIdForPostNumber(postNumber);
        if (postId) {
          return postStream.findLoadedPost(postId);
        }
      })
      .filter((post) => post);

    this.maxContext = this.allPosts.length / 2;
    this.contextValue = 1;

    this.updateHtmlContext();
  }

  @action
  updateHtmlContext() {
    let context = [];

    const start = this.allPosts.length - this.contextValue * 2;
    for (let i = start; i < this.allPosts.length; i++) {
      const post = this.allPosts[i];
      context.push(`<p><b>${post.username}:</b></p>`);
      context.push(post.cooked);
    }
    this.htmlContext = htmlSafe(context.join("\n"));
  }

  @action
  async copyContext() {
    const from =
      this.allPosts[this.allPosts.length - this.contextValue * 2].post_number;
    const to = this.args.model.post_number;

    await copyConversation(this.args.model.topic, from, to);
    this.justCopiedText = I18n.t("discourse_ai.ai_bot.conversation_shared");

    discourseLater(() => {
      this.justCopiedText = "";
    }, 2000);
  }

  <template>
    <DModal
      class="ai-share-modal"
      @title={{i18n "discourse_ai.ai_bot.share_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="ai-share-modal__preview">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <div class="ai-share-modal__slider">
          <Input
            @type="range"
            min="1"
            max={{this.maxContext}}
            @value={{this.contextValue}}
            {{on "change" this.updateHtmlContext}}
          />
          <div class="ai-share-modal__context">
            {{i18n "discourse_ai.ai_bot.share_modal.context"}}
            {{this.contextValue}}
          </div>
        </div>
        <DButton
          class="btn-primary confirm"
          @icon="copy"
          @action={{this.copyContext}}
          @label="discourse_ai.ai_bot.share_modal.copy"
        />
        <span class="ai-share-modal__just-copied">{{this.justCopiedText}}</span>
      </:footer>
    </DModal>
  </template>
}
