import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DiffStreamer from "../../lib/diff-streamer";
import SmoothStreamer from "../../lib/smooth-streamer";
import AiIndicatorWave from "../ai-indicator-wave";

export default class ModalDiffModal extends Component {
  @service currentUser;
  @service messageBus;

  @tracked loading = false;
  @tracked diffStreamer = new DiffStreamer(this.args.model.selectedText);
  @tracked suggestion = "";
  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.suggestion,
    (newValue) => (this.suggestion = newValue)
  );

  constructor() {
    super(...arguments);
    this.suggestChanges();
  }

  get isStreaming() {
    return this.diffStreamer.isStreaming || this.smoothStreamer.isStreaming;
  }

  @bind
  subscribe() {
    const channel = "/discourse-ai/ai-helper/stream_composer_suggestion";
    this.messageBus.subscribe(channel, this.updateResult);
  }

  @bind
  unsubscribe() {
    const channel = "/discourse-ai/ai-helper/stream_composer_suggestion";
    this.messageBus.subscribe(channel, this.updateResult);
  }

  @action
  async updateResult(result) {
    this.loading = false;

    if (this.args.model.showResultAsDiff) {
      this.diffStreamer.updateResult(result, "result");
    } else {
      this.smoothStreamer.updateResult(result, "result");
    }
  }

  @action
  async suggestChanges() {
    this.smoothStreamer.resetStreaming();
    this.diffStreamer.reset();

    try {
      return await ajax("/discourse-ai/ai-helper/stream_suggestion", {
        method: "POST",
        data: {
          location: "composer",
          mode: this.args.model.mode,
          text: this.args.model.selectedText,
          custom_prompt: this.args.model.customPromptValue,
          force_default_locale: true,
        },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  triggerConfirmChanges() {
    this.args.closeModal();

    if (this.suggestion) {
      this.args.model.toolbarEvent.replaceText(
        this.args.model.selectedText,
        this.suggestion
      );
    }

    if (this.args.model.showResultAsDiff && this.diffStreamer.suggestion) {
      this.args.model.toolbarEvent.replaceText(
        this.args.model.selectedText,
        this.diffStreamer.suggestion
      );
    }
  }

  <template>
    <DModal
      class="composer-ai-helper-modal"
      @title={{i18n "discourse_ai.ai_helper.context_menu.changes"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div {{didInsert this.subscribe}} {{willDestroy this.unsubscribe}}>
          {{#if this.loading}}
            <div class="composer-ai-helper-modal__loading">
              <CookText @rawText={{@model.selectedText}} />
            </div>
          {{else}}
            <div
              class={{concatClass
                "composer-ai-helper-modal__suggestion"
                "streamable-content"
                (if this.isStreaming "streaming")
                (if @model.showResultAsDiff "inline-diff")
              }}
            >
              {{#if @model.showResultAsDiff}}
                {{htmlSafe this.diffStreamer.diff}}
              {{else}}
                {{#if this.smoothStreamer.isStreaming}}
                  <CookText
                    @rawText={{this.smoothStreamer.renderedText}}
                    class="cooked"
                  />
                {{else}}
                  <div class="composer-ai-helper-modal__old-value">
                    {{@model.selectedText}}
                  </div>
                  <div class="composer-ai-helper-modal__new-value">
                    <CookText
                      @rawText={{this.smoothStreamer.renderedText}}
                      class="cooked"
                    />
                  </div>
                {{/if}}
              {{/if}}
            </div>
          {{/if}}
        </div>
      </:body>

      <:footer>
        {{#if this.loading}}
          <DButton
            class="btn-primary"
            @label="discourse_ai.ai_helper.context_menu.loading"
            @disabled={{true}}
          >
            <AiIndicatorWave @loading={{this.loading}} />
          </DButton>
        {{else}}
          <DButton
            class="btn-primary confirm"
            @disabled={{this.isStreaming}}
            @action={{this.triggerConfirmChanges}}
            @label="discourse_ai.ai_helper.context_menu.confirm"
          />
          <DButton
            class="btn-flat discard"
            @action={{@closeModal}}
            @label="discourse_ai.ai_helper.context_menu.discard"
          />
          <DButton
            class="regenerate"
            @icon="arrows-rotate"
            @action={{this.suggestChanges}}
            @label="discourse_ai.ai_helper.context_menu.regen"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
