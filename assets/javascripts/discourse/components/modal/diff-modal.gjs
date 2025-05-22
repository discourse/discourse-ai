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
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DiffStreamer from "../../lib/diff-streamer";
import SmoothStreamer from "../../lib/smooth-streamer";
import AiIndicatorWave from "../ai-indicator-wave";

export default class ModalDiffModal extends Component {
  @service currentUser;
  @service messageBus;

  @tracked loading = false;
  @tracked finalResult = "";
  @tracked selectedText = escapeExpression(this.args.model.selectedText);
  @tracked diffStreamer = new DiffStreamer(this.selectedText);
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

  get diffResult() {
    if (this.diffStreamer.diff?.length > 0) {
      return this.diffStreamer.diff;
    }

    // Prevents flash by showing the
    // original text when the diff is empty
    return this.selectedText;
  }

  get isStreaming() {
    return this.diffStreamer.isStreaming || this.smoothStreamer.isStreaming;
  }

  get primaryBtnLabel() {
    return this.loading
      ? i18n("discourse_ai.ai_helper.context_menu.loading")
      : i18n("discourse_ai.ai_helper.context_menu.confirm");
  }

  get primaryBtnDisabled() {
    return this.loading || this.isStreaming;
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

    if (result.done) {
      this.finalResult = result.result;
    }

    if (result.done) {
      this.loading = false;
    }

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
      this.loading = true;
      return await ajax("/discourse-ai/ai-helper/stream_suggestion", {
        method: "POST",
        data: {
          location: "composer",
          mode: this.args.model.mode,
          text: this.selectedText,
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
        this.selectedText,
        this.suggestion
      );
    }

    const finalResult =
      this.finalResult?.length > 0
        ? this.finalResult
        : this.diffStreamer.suggestion;
    if (this.args.model.showResultAsDiff && finalResult) {
      this.args.model.toolbarEvent.replaceText(this.selectedText, finalResult);
    }
  }

  <template>
    <DModal
      class="composer-ai-helper-modal"
      @title={{i18n "discourse_ai.ai_helper.context_menu.changes"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div
          {{didInsert this.subscribe}}
          {{willDestroy this.unsubscribe}}
          class="text-preview"
        >
          {{#if this.loading}}
            <div class="composer-ai-helper-modal__loading">
              {{~@model.selectedText~}}
            </div>
          {{else}}
            <div
              class={{concatClass
                "composer-ai-helper-modal__suggestion"
                "streamable-content"
                (if this.isStreaming "streaming")
                (if @model.showResultAsDiff "inline-diff")
                (if this.diffStreamer.isThinking "thinking")
              }}
            >
              {{~#if @model.showResultAsDiff~}}
                <span class="diff-inner">{{htmlSafe this.diffResult}}</span>
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
        <DButton
          class="btn-primary confirm"
          @disabled={{this.primaryBtnDisabled}}
          @action={{this.triggerConfirmChanges}}
          @translatedLabel={{this.primaryBtnLabel}}
        >
          {{#if this.loading}}
            <AiIndicatorWave @loading={{this.loading}} />
          {{/if}}
        </DButton>
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
      </:footer>
    </DModal>
  </template>
}
