import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class RagUploadProgress extends Component {
  @service messageBus;

  @tracked updatedProgress = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(
      `/discourse-ai/ai-persona-rag/${this.args.upload.id}`
    );
  }

  @action
  trackProgress() {
    this.messageBus.subscribe(
      `/discourse-ai/ai-persona-rag/${this.args.upload.id}`,
      this.onIndexingUpdate
    );
  }

  @bind
  onIndexingUpdate(data) {
    // Order not guaranteed. Discard old updates.
    if (!this.updatedProgress || this.updatedProgress.left > data.left) {
      this.updatedProgress = data;
    }
  }

  get calculateProgress() {
    return Math.ceil((this.progress.indexed * 100) / this.progress.total);
  }

  get fullyIndexed() {
    return this.progress && this.progress.left === 0;
  }

  get progress() {
    if (this.updatedProgress) {
      return this.updatedProgress;
    } else if (this.args.ragIndexingStatuses) {
      return this.args.ragIndexingStatuses[this.args.upload.id];
    } else {
      return [];
    }
  }

  <template>
    <td
      class="persona-rag-uploader__upload-status"
      {{didInsert this.trackProgress}}
    >
      {{#if this.progress}}
        {{#if this.fullyIndexed}}
          <span class="indexed">
            {{icon "check"}}
            {{I18n.t "discourse_ai.ai_persona.uploads.indexed"}}
          </span>
        {{else}}
          <span class="indexing">
            {{icon "robot"}}
            {{I18n.t "discourse_ai.ai_persona.uploads.indexing"}}
            {{this.calculateProgress}}%
          </span>
        {{/if}}
      {{else}}
        <span class="uploaded">{{I18n.t
            "discourse_ai.ai_persona.uploads.uploaded"
          }}</span>
      {{/if}}
    </td>
  </template>
}
