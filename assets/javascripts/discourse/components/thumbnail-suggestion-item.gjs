import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class ThumbnailSuggestionItem extends Component {
  @tracked selected = false;
  @tracked selectIcon = "far-circle";
  @tracked selectLabel = "discourse_ai.ai_helper.thumbnail_suggestions.select";

  @action
  toggleSelection(thumbnail) {
    if (this.selected) {
      this.selectIcon = "far-circle";
      this.selectLabel = "discourse_ai.ai_helper.thumbnail_suggestions.select";
      this.selected = false;
      return this.args.removeSelection(thumbnail);
    }

    this.selectIcon = "check-circle";
    this.selectLabel = "discourse_ai.ai_helper.thumbnail_suggestions.selected";
    this.selected = true;
    return this.args.addSelection(thumbnail);
  }

  <template>
    <div class="ai-thumbnail-suggestions__item">
      <DButton
        class={{if this.selected "btn-primary" ""}}
        @icon={{this.selectIcon}}
        @label={{this.selectLabel}}
        @action={{this.toggleSelection}}
        @actionParam={{@thumbnail}}
      />
      <img
        src={{@thumbnail.url}}
        loading="lazy"
        width={{@thumbnail.thumbnail_width}}
        height={{@thumbnail.thumbnail_height}}
      />
    </div>
  </template>
}
