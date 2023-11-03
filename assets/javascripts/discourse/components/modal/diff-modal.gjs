import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import I18n from "I18n";

const t = I18n.t.bind(I18n);

export default class ModalDiffModal extends Component {
  @action
  triggerConfirmChanges() {
    this.args.closeModal();
    this.args.confirm();
  }

  @action
  triggerRevertChanges() {
    this.args.closeModal();
    this.args.revert();
  }

  <template>
    <DModal
      class="composer-ai-helper-modal"
      @title={{t "discourse_ai.ai_helper.context_menu.changes"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#if @diff}}
          {{htmlSafe @diff}}
        {{else}}
          <div class="composer-ai-helper-modal__old-value">
            {{@oldValue}}
          </div>

          <div class="composer-ai-helper-modal__new-value">
            {{@newValue}}
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
          class="btn-flat"
          @action={{this.triggerRevertChanges}}
          @label="discourse_ai.ai_helper.context_menu.revert"
        />
      </:footer>
    </DModal>
  </template>
}
