import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";

export default class ModalDiffModal extends Component {
  @service currentUser;
  @tracked loading = false;
  @tracked diff;
  suggestion = "";

  PROOFREAD_ID = -303;

  constructor() {
    super(...arguments);
    this.diff = this.args.model.diff;

    next(() => {
      if (this.args.model.toolbarEvent) {
        this.loadDiff();
      }
    });
  }

  async loadDiff() {
    this.loading = true;

    try {
      const suggestion = await ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: this.PROOFREAD_ID,
          text: this.selectedText,
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

  get selectedText() {
    const selected = this.args.model.toolbarEvent.selected;

    if (selected.value === "") {
      return selected.pre + selected.post;
    }

    return selected.value;
  }

  @action
  triggerConfirmChanges() {
    this.args.closeModal();
    if (this.args.model.confirm) {
      this.args.model.confirm();
    }

    if (this.args.model.toolbarEvent && this.suggestion) {
      this.args.model.toolbarEvent.replaceText(
        this.selectedText,
        this.suggestion
      );
    }
  }

  @action
  triggerRevertChanges() {
    this.args.model.revert();
    this.args.closeModal();
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
            <CookText @rawText={{this.selectedText}} />
          </div>
        {{else}}
          {{#if this.diff}}
            {{htmlSafe this.diff}}
          {{else}}
            <div class="composer-ai-helper-modal__old-value">
              {{@model.oldValue}}
            </div>

            <div class="composer-ai-helper-modal__new-value">
              {{@model.newValue}}
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
          />
        {{else}}
          <DButton
            class="btn-primary confirm"
            @action={{this.triggerConfirmChanges}}
            @label="discourse_ai.ai_helper.context_menu.confirm"
          />
          {{#if @model.revert}}
            <DButton
              class="btn-flat revert"
              @action={{this.triggerRevertChanges}}
              @label="discourse_ai.ai_helper.context_menu.revert"
            />
          {{/if}}
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
