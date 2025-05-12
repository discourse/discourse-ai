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
import SmoothStreamer from "../../lib/smooth-streamer";
import AiIndicatorWave from "../ai-indicator-wave";
import { cancel, later } from "@ember/runloop";

const WORD_TYPING_DELAY = 200;

export default class ModalDiffModal extends Component {
  @service currentUser;
  @service messageBus;

  @tracked loading = false;
  @tracked diff;
  @tracked suggestion = "";
  @tracked isStreaming = false;
  @tracked lastResultText = "";
  // @tracked
  // smoothStreamer = new SmoothStreamer(
  //   () => this.suggestion,
  //   (newValue) => (this.suggestion = newValue)
  // );
  @tracked finalDiff = "";
  @tracked words = [];
  originalWords = [];
  typingTimer = null;
  currentWordIndex = 0;

  constructor() {
    super(...arguments);
    this.suggestChanges();
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

  compareText(oldText = "", newText = "", opts = {}) {
    const oldWords = oldText.trim().split(/\s+/);
    const newWords = newText.trim().split(/\s+/);

    const diff = [];
    let i = 0;

    while (i < newWords.length) {
      const oldWord = oldWords[i];
      const newWord = newWords[i];

      let wordHTML;
      if (oldWord === undefined) {
        wordHTML = `<ins>${newWord}</ins>`;
      } else if (oldWord !== newWord) {
        wordHTML = `<del>${oldWord}</del> <ins>${newWord}</ins>`;
      } else {
        wordHTML = newWord;
      }

      if (i === newWords.length - 1 && opts.markLastWord) {
        wordHTML = `<mark class="highlight">${wordHTML}</mark>`;
      }

      diff.push(wordHTML);
      i++;
    }

    return diff.join(" ");
  }

  @action
  async updateResult(result) {
    this.loading = false;

    const newText = result.result;
    const diffText = newText.slice(this.lastResultText.length).trim();
    const newWords = diffText.split(/\s+/).filter(Boolean);

    if (newWords.length > 0) {
      this.words.push(...newWords);
      if (!this.typingTimer) {
        this.streamNextWord();
      }
    }

    if (result.done) {
      // this.finalDiff = result.diff;
    }

    this.lastResultText = newText;
    this.isStreaming = !result.done;
  }

  streamNextWord() {
    if (this.currentWordIndex === this.words.length) {
      this.diff = this.compareText(
        this.args.model.selectedText,
        this.suggestion,
        { markLastWord: false }
      );
    }

    if (this.currentWordIndex < this.words.length) {
      this.suggestion += this.words[this.currentWordIndex] + " ";
      this.diff = this.compareText(
        this.args.model.selectedText,
        this.suggestion,
        { markLastWord: true }
      );

      this.currentWordIndex++;
      this.typingTimer = later(this, this.streamNextWord, WORD_TYPING_DELAY);
    } else {
      this.typingTimer = null;
    }
  }

  @action
  async suggestChanges() {
    // this.smoothStreamer.resetStreaming();
    this.diff = null;
    this.suggestion = "";
    this.loading = true;
    this.lastResultText = "";
    this.words = [];
    this.currentWordIndex = 0;

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
              }}
            >
              {{!-- <CookText @rawText={{this.diff}} class="cooked" /> --}}
              {{htmlSafe this.diff}}
              {{!-- <div class="composer-ai-helper-modal__old-value">
                {{@model.selectedText}}
              {{!-- {{#if this.smoothStreamer.isStreaming}}
                <CookText
                  @rawText={{this.smoothStreamer.renderedText}}
                  class="cooked"
                />
              {{else}}
                {{#if this.diff}}
                  {{htmlSafe this.diff}}
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
              {{/if}} --}}
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
