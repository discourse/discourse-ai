import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import ComboBox from "select-kit/components/combo-box";

export default class AiSpam extends Component {
  @service siteSettings;
  @tracked
  stats = {
    scanned_count: 0,
    spam_detected: 0,
    false_positives: 0,
    false_negatives: 0,
    daily_data: [],
  };
  @tracked isEnabled = false;
  @tracked selectedLLM = null;
  @tracked customInstructions = "";
  @tracked isLoadingStats = false;

  constructor() {
    super(...arguments);
  }

  get availableLLMs() {
    return (this.args.model?.available_llms || []).map((llm) => ({
      id: llm.id,
      name: llm.name,
    }));
  }

  @action
  async loadStats() {
    this.isLoadingStats = true;
    try {
      const response = await ajax("/admin/plugins/discourse-ai/ai-spam.json");
      this.stats = response.stats;
      this.isEnabled = response.is_enabled;
      this.selectedLLM = response.selected_llm;
      this.customInstructions = response.custom_instructions;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoadingStats = false;
    }
  }

  @action
  async toggleEnabled() {
    try {
      const response = await ajax(
        "/admin/plugins/discourse-ai/ai-spam/toggle",
        {
          type: "PUT",
          data: { enabled: !this.isEnabled },
        }
      );
      this.isEnabled = response.is_enabled;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async updateLLM(value) {
    try {
      await ajax("/admin/plugins/discourse-ai/ai-spam/llm", {
        type: "PUT",
        data: { llm: value },
      });
      this.selectedLLM = value;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async saveInstructions() {
    try {
      await ajax("/admin/plugins/discourse-ai/ai-spam/instructions", {
        type: "PUT",
        data: { instructions: this.customInstructions },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="ai-spam">
      <section class="ai-spam__settings">
        <h3 class="ai-spam__settings-title">{{i18n
            "discourse_ai.spam.title"
          }}</h3>

        <div class="ai-spam__toggle">
          <DToggleSwitch
            @state={{this.enabled}}
            {{on "click" this.toggleEnabled}}
          />
        </div>

        <div class="ai-spam__llm">
          <label class="ai-spam__llm-label">{{i18n
              "discourse_ai.spam.select_llm"
            }}</label>
          <ComboBox
            @value={{this.selectedLLM}}
            @content={{this.availableLLMs}}
            @onChange={{this.updateLLM}}
            @options={{hash disabled=(not this.isEnabled)}}
            class="ai-spam__llm-selector"
          />
        </div>

        <div class="ai-spam__instructions">
          <label class="ai-spam__instructions-label">
            {{i18n "discourse_ai.spam.custom_instructions"}}
            <DTooltip
              @icon="question-circle"
              @content={{i18n "discourse_ai.spam.custom_instructions_help"}}
            />
          </label>
          <textarea
            class="ai-spam__instructions-input"
            {{on
              "input"
              (fn (mut this.customInstructions) value="target.value")
            }}
            disabled={{not this.isEnabled}}
          >{{this.customInstructions}}</textarea>
          <DButton
            @action={{this.saveInstructions}}
            @icon="save"
            @label="save"
            @disabled={{not this.isEnabled}}
            class="ai-spam__instructions-save btn-primary"
          />
        </div>
      </section>

      <section class="ai-spam__stats">
        <h3 class="ai-spam__stats-title">{{i18n
            "discourse_ai.spam.last_seven_days"
          }}</h3>

        {{#if this.isLoadingStats}}
          <div class="ai-spam__loading"></div>
        {{else}}
          <div class="ai-spam__metrics">
            <div class="ai-spam__metrics-item">
              <span class="ai-spam__metrics-label">{{i18n
                  "discourse_ai.spam.scanned_count"
                }}</span>
              <span
                class="ai-spam__metrics-value"
              >{{this.stats.scanned_count}}</span>
            </div>
            <div class="ai-spam__metrics-item">
              <span class="ai-spam__metrics-label">{{i18n
                  "discourse_ai.spam.spam_detected"
                }}</span>
              <span
                class="ai-spam__metrics-value"
              >{{this.stats.spam_detected}}</span>
            </div>
            <div class="ai-spam__metrics-item">
              <span class="ai-spam__metrics-label">{{i18n
                  "discourse_ai.spam.false_positives"
                }}</span>
              <span
                class="ai-spam__metrics-value"
              >{{this.stats.false_positives}}</span>
            </div>
            <div class="ai-spam__metrics-item">
              <span class="ai-spam__metrics-label">{{i18n
                  "discourse_ai.spam.false_negatives"
                }}</span>
              <span
                class="ai-spam__metrics-value"
              >{{this.stats.false_negatives}}</span>
            </div>
          </div>

          <div class="ai-spam__reports">
            <h3 class="ai-spam__reports-title">{{i18n
                "discourse_ai.spam.reports"
              }}</h3>
            <div class="ai-spam__reports-links">
              <a
                href="/review?status=false_positive"
                class="ai-spam__reports-link"
              >
                {{i18n "discourse_ai.spam.view_false_positives"}}
              </a>
              <a
                href="/review?status=missed_spam"
                class="ai-spam__reports-link"
              >
                {{i18n "discourse_ai.spam.view_missed_spam"}}
              </a>
            </div>
          </div>
        {{/if}}
      </section>
    </div>
  </template>
}
