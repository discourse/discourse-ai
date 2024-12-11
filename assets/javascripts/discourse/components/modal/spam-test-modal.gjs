import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

export default class SpamTestModal extends Component {
  @tracked testResult;
  @tracked isLoading = false;
  @tracked postUrl = "";
  @tracked scanLog = "";

  @action
  async runTest() {
    this.isLoading = true;
    try {
      const response = await ajax(
        `/admin/plugins/discourse-ai/ai-spam/test.json`,
        {
          type: "POST",
          data: {
            post_url: this.postUrl,
            custom_instructions: this.args.model.customInstructions,
          },
        }
      );

      this.testResult = response.is_spam
        ? I18n.t("discourse_ai.usage.test_modal.spam")
        : I18n.t("discourse_ai.usage.test_modal.not_spam");
      this.scanLog = response.log;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  get isSpam() {
    return this.testResult === I18n.t("discourse_ai.usage.test_modal.spam");
  }

  <template>
    <DModal
      @title={{I18n.t "discourse_ai.spam.test_modal.title"}}
      @closeModal={{@closeModal}}
      @bodyClass="spam-test-modal__body"
      class="spam-test-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{I18n.t
              "discourse_ai.spam.test_modal.post_url_label"
            }}</label>
          <input
            {{on "input" (withEventValue (fn (mut this.postUrl)))}}
            type="text"
            placeholder={{I18n.t
              "discourse_ai.spam.test_modal.post_url_placeholder"
            }}
          />
        </div>

        {{#if this.testResult}}
          <div class="spam-test-modal__test-result">
            <h3>{{I18n.t "discourse_ai.spam.test_modal.result"}}</h3>
            <div
              class="spam-test-modal__verdict
                {{if this.isSpam 'is-spam' 'not-spam'}}"
            >
              {{this.testResult}}
            </div>
            {{#if this.scanLog}}
              <div class="spam-test-modal__log">
                <h4>{{I18n.t "discourse_ai.spam.test_modal.scan_log"}}</h4>
                <pre>{{this.scanLog}}</pre>
              </div>
            {{/if}}
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          @action={{this.runTest}}
          @label="discourse_ai.spam.test_modal.run"
          @disabled={{this.isLoading}}
          class="btn-primary spam-test-modal__run-button"
        />
      </:footer>
    </DModal>
  </template>
}
