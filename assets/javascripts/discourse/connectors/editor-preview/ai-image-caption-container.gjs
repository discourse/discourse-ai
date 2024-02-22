import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { inject as service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DTextarea from "discourse/components/d-textarea";
import autoFocus from "discourse/modifiers/auto-focus";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { IMAGE_MARKDOWN_REGEX } from "../../lib/utilities";

export default class AiImageCaptionContainer extends Component {
  @service imageCaptionPopup;
  @service appEvents;
  @service composer;

  @action
  updateCaption(event) {
    event.preventDefault();
    this.imageCaptionPopup.newCaption = event.target.value;
  }

  @action
  saveCaption() {
    const index = this.imageCaptionPopup.imageIndex;
    const matchingPlaceholder =
      this.composer.model.reply.match(IMAGE_MARKDOWN_REGEX);

    if (matchingPlaceholder) {
      const match = matchingPlaceholder[index];
      const replacement = match.replace(
        IMAGE_MARKDOWN_REGEX,
        `![${this.imageCaptionPopup.newCaption}|$2$3$4]($5)`
      );

      if (match) {
        this.appEvents.trigger("composer:replace-text", match, replacement);
      }
    }

    this.hidePopup();
  }

  @action
  resizeTextarea(target) {
    const style = window.getComputedStyle(target);

    // scrollbars will show based on scrollHeight alone
    // so we need to consider borders too
    const borderTopWidth = parseInt(style.borderTopWidth, 10);
    const borderBottomWidth = parseInt(style.borderBottomWidth, 10);

    target.scrollTop = 0;
    target.style.height = `${
      target.scrollHeight + borderTopWidth + borderBottomWidth
    }px`;
  }

  @action
  hidePopup() {
    this.imageCaptionPopup.showPopup = false;
  }

  <template>
    {{#if this.imageCaptionPopup.showPopup}}
      <div
        class="composer-popup education-message ai-caption-popup"
        {{willDestroy this.hidePopup}}
      >
        <ConditionalLoadingSpinner
          @condition={{this.imageCaptionPopup.loading}}
        >
          <DTextarea
            {{didInsert this.resizeTextarea}}
            {{didUpdate this.resizeTextarea this.imageCaptionPopup.newCaption}}
            @value={{this.imageCaptionPopup.newCaption}}
            {{on "change" this.updateCaption}}
            {{autoFocus}}
          />
        </ConditionalLoadingSpinner>

        <div class="actions">
          <DButton
            class="btn-primary"
            @label="discourse_ai.ai_helper.image_caption.save_caption"
            @icon="check"
            @action={{this.saveCaption}}
          />
          <DButton
            class="btn-flat"
            @label="cancel"
            @action={{this.hidePopup}}
          />

          <span class="credits">
            {{icon "discourse-sparkles"}}
            <span>{{i18n "discourse_ai.ai_helper.image_caption.credits"}}</span>
          </span>
        </div>
      </div>
    {{/if}}
  </template>
}
