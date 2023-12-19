import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import i18n from "discourse-common/helpers/i18n";
import ThumbnailSuggestionItem from "../thumbnail-suggestion-item";

export default class ThumbnailSuggestions extends Component {
  @tracked selectedImages = [];

  get isDisabled() {
    return this.selectedImages.length === 0;
  }

  @action
  addSelection(selection) {
    const thumbnailMarkdown = `![${selection.original_filename}|${selection.width}x${selection.height}](${selection.short_url})`;
    this.selectedImages = [...this.selectedImages, thumbnailMarkdown];
  }

  @action
  removeSelection(selection) {
    const thumbnailMarkdown = `![${selection.original_filename}|${selection.width}x${selection.height}](${selection.short_url})`;

    this.selectedImages = this.selectedImages.filter((thumbnail) => {
      if (thumbnail !== thumbnailMarkdown) {
        return thumbnail;
      }
    });
  }

  @action
  appendSelectedImages() {
    const composerValue = this.args.composer?.reply || "";

    const newValue = composerValue.concat(
      "\n\n",
      this.selectedImages.join("\n")
    );
    this.args.composer.set("reply", newValue);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="thumbnail-suggestions-modal"
      @title={{i18n "discourse_ai.ai_helper.thumbnail_suggestions.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="ai-thumbnail-suggestions">
          {{#each @thumbnails as |thumbnail|}}
            <ThumbnailSuggestionItem
              @thumbnail={{thumbnail}}
              @addSelection={{this.addSelection}}
              @removeSelection={{this.removeSelection}}
            />
          {{/each}}
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.appendSelectedImages}}
          @label="save"
          @disabled={{this.isDisabled}}
          class="btn-primary create"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
