import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";

export default class ModalDiffModal extends Component {
  @action
  triggerConfirmChanges() {
    this.args.closeModal();
    this.args.model.confirm();
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
        {{#if @model.diff}}
          {{htmlSafe @model.diff}}
        {{else}}
          <div class="composer-ai-helper-modal__old-value">
            {{@model.oldValue}}
          </div>

          <div class="composer-ai-helper-modal__new-value">
            {{@model.newValue}}
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          class="btn-primary confirm"
          @action={{this.triggerConfirmChanges}}
          @label="discourse_ai.ai_helper.context_menu.confirm"
        />
        <DButton
          class="btn-flat revert"
          @action={{this.triggerRevertChanges}}
          @label="discourse_ai.ai_helper.context_menu.revert"
        />
      </:footer>
    </DModal>
  </template>
}
