import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import autoFocus from "discourse/modifiers/auto-focus";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { IMAGE_MARKDOWN_REGEX } from "../lib/utilities";

export default class AiImageCaptionContainer extends Component {
  @service imageCaptionPopup;
  @service appEvents;
  @service composer;
  @tracked newCaption = "Another caption";

  @action
  updateCaption(event) {
    event.preventDefault();
    this.newCaption = event.target.value;
  }

  @action
  saveCaption() {
    const index = this.imageCaptionPopup.imageIndex;
    const matchingPlaceholder =
      this.composer.model.reply.match(IMAGE_MARKDOWN_REGEX);
    const match = matchingPlaceholder[index];
    const replacement = match.replace(
      IMAGE_MARKDOWN_REGEX,
      `![${this.newCaption}|$2$3$4]($5)`
    );
    this.appEvents.trigger("composer:replace-text", match, replacement);
    this.imageCaptionPopup.showPopup = false;
  }

  <template>
    {{#if this.imageCaptionPopup.showPopup}}

      <div class="composer-popup education-message ai-caption-popup">
        <DButton
          @class="btn-transparent close"
          @title="close"
          @action={{fn (mut this.imageCaptionPopup.showPopup) false}}
          @icon="times"
        />
        <textarea
          {{on "input" this.updateCaption}}
          {{autoFocus}}
        >{{this.newCaption}}</textarea>

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
            @action={{fn (mut this.imageCaptionPopup.showPopup) false}}
          />

          <span class="credits">
            {{icon "discourse-sparkles"}}
            {{i18n "discourse_ai.ai_helper.image_caption.credits"}}
          </span>
        </div>
      </div>
    {{/if}}
  </template>
}
