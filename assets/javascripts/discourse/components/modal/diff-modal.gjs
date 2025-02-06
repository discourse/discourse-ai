import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AiIndicatorWave from "../ai-indicator-wave";

export default class ModalDiffModal extends Component {
  @service currentUser;
  @tracked loading = false;
  @tracked diff;
  @tracked suggestion = "";

  constructor() {
    super(...arguments);
    this.suggestChanges();
  }

  @action
  async suggestChanges() {
    this.loading = true;

    try {
      const suggestion = await ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: this.args.model.mode,
          text: this.args.model.selectedText,
          custom_prompt: this.args.model.customPromptValue,
          force_default_locale: true,
        },
      });

      this.diff = suggestion.diff;
      this.suggestion = suggestion.suggestions[0];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
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
        {{#if this.loading}}
          <div class="composer-ai-helper-modal__loading">
            <CookText @rawText={{@model.selectedText}} />
          </div>
        {{else}}
          {{#if this.diff}}
            {{htmlSafe this.diff}}
          {{else}}
            <div class="composer-ai-helper-modal__old-value">
              {{@model.selectedText}}
            </div>

            <div class="composer-ai-helper-modal__new-value">
              {{this.suggestion}}
            </div>
          {{/if}}
        {{/if}}

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
