import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/components/d-tooltip";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import ComboBox from "select-kit/components/combo-box";

export default class AiSpam extends Component {
  @service siteSettings;
  @service toasts;

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

  constructor() {
    super(...arguments);
    this.initializeFromModel();
  }

  @action
  initializeFromModel() {
    const model = this.args.model;
    this.isEnabled = model.is_enabled;
    this.selectedLLM = "custom:" + model.llm_id;
    this.customInstructions = model.custom_instructions;
    this.stats = model.stats;
  }

  get availableLLMs() {
    return this.args.model?.available_llms || [];
  }

  @action
  async toggleEnabled() {
    try {
      // so UI responds immediately
      this.isEnabled = !this.isEnabled;
      const response = await ajax("/admin/plugins/discourse-ai/ai-spam.json", {
        type: "PUT",
        data: { is_enabled: this.isEnabled },
      });
      this.isEnabled = response.is_enabled;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async updateLLM(value) {
    this.selectedLLM = value;
  }

  @action
  async save() {
    const llmId = this.selectedLLM.toString().split(":")[1];
    try {
      await ajax("/admin/plugins/discourse-ai/ai-spam.json", {
        type: "PUT",
        data: {
          llm_model_id: llmId,
          custom_instructions: this.customInstructions,
        },
      });
      this.toasts.success({
        data: { message: i18n("discourse_ai.spam.settings_saved") },
        duration: 2000,
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get metrics() {
    return [
      {
        label: "discourse_ai.spam.scanned_count",
        value: this.stats.scanned_count,
      },
      {
        label: "discourse_ai.spam.spam_detected",
        value: this.stats.spam_detected,
      },
      {
        label: "discourse_ai.spam.false_positives",
        value: this.stats.false_positives,
      },
      {
        label: "discourse_ai.spam.false_negatives",
        value: this.stats.false_negatives,
      },
    ];
  }

  <template>
    <div class="ai-spam">
      <section class="ai-spam__settings">
        <h3 class="ai-spam__settings-title">{{i18n
            "discourse_ai.spam.title"
          }}</h3>

        <div class="control-group ai-spam__enabled">
          <DToggleSwitch
            class="ai-spam__toggle"
            @state={{this.isEnabled}}
            @label="discourse_ai.spam.enable"
            {{on "click" this.toggleEnabled}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.spam.spam_tip"}}
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
            class="ai-spam__llm-selector"
          />
        </div>

        <div class="ai-spam__instructions">
          <label class="ai-spam__instructions-label">
            {{i18n "discourse_ai.spam.custom_instructions"}}
            <DTooltip
              @icon="circle-question"
              @content={{i18n "discourse_ai.spam.custom_instructions_help"}}
            />
          </label>
          <textarea
            class="ai-spam__instructions-input"
            placeholder={{i18n
              "discourse_ai.spam.custom_instructions_placeholder"
            }}
            {{on "input" (withEventValue (fn (mut this.customInstructions)))}}
          >{{this.customInstructions}}</textarea>
          <DButton
            @action={{this.save}}
            @label="save"
            class="ai-spam__instructions-save btn-primary"
          />
        </div>
      </section>

      <section class="ai-spam__stats">
        <h3 class="ai-spam__stats-title">{{i18n
            "discourse_ai.spam.last_seven_days"
          }}</h3>

        <div class="ai-spam__metrics">
          {{#each this.metrics as |metric|}}
            <div class="ai-spam__metrics-item">
              <span class="ai-spam__metrics-label">{{i18n metric.label}}</span>
              <span class="ai-spam__metrics-value">{{metric.value}}</span>
            </div>
          {{/each}}
        </div>
      </section>
    </div>
  </template>
}
