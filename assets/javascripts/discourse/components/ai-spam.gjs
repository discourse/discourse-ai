import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DStatTiles from "discourse/components/d-stat-tiles";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/components/d-tooltip";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ComboBox from "select-kit/components/combo-box";
import SpamTestModal from "./modal/spam-test-modal";

export default class AiSpam extends Component {
  @service siteSettings;
  @service toasts;
  @service modal;

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

    if (model.llm_id) {
      this.selectedLLM = "custom:" + model.llm_id;
    } else {
      if (this.availableLLMs.length) {
        this.selectedLLM = this.availableLLMs[0].id;
        this.autoSelectedLLM = true;
      }
    }
    this.customInstructions = model.custom_instructions;
    this.stats = model.stats;
  }

  get availableLLMs() {
    return this.args.model?.available_llms || [];
  }

  @action
  async toggleEnabled() {
    this.isEnabled = !this.isEnabled;
    const data = { is_enabled: this.isEnabled };
    if (this.autoSelectedLLM) {
      data.llm_model_id = this.llmId;
    }
    try {
      const response = await ajax("/admin/plugins/discourse-ai/ai-spam.json", {
        type: "PUT",
        data,
      });
      this.autoSelectedLLM = false;
      this.isEnabled = response.is_enabled;
    } catch (error) {
      this.isEnabled = !this.isEnabled;
      popupAjaxError(error);
    }
  }

  get llmId() {
    return this.selectedLLM.toString().split(":")[1];
  }

  @action
  async updateLLM(value) {
    this.selectedLLM = value;
  }

  @action
  async save() {
    try {
      await ajax("/admin/plugins/discourse-ai/ai-spam.json", {
        type: "PUT",
        data: {
          llm_model_id: this.llmId,
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

  @action
  showTestModal() {
    this.modal.show(SpamTestModal, {
      model: {
        customInstructions: this.customInstructions,
        llmId: this.llmId,
      },
    });
  }

  get metrics() {
    const detected = {
      label: i18n("discourse_ai.spam.spam_detected"),
      value: this.stats.spam_detected,
    };

    const falsePositives = {
      label: i18n("discourse_ai.spam.false_positives"),
      value: this.stats.false_positives,
      tooltip: i18n("discourse_ai.spam.stat_tooltips.incorrectly_flagged"),
    };

    const falseNegatives = {
      label: i18n("discourse_ai.spam.false_negatives"),
      value: this.stats.false_negatives,
      tooltip: i18n("discourse_ai.spam.stat_tooltips.missed_spam"),
    };

    if (this.args.model.flagging_username) {
      detected.href = getURL(
        `/review?flagged_by=${this.args.model.flagging_username}&status=all&sort_order=created_at`
      );

      falsePositives.href = getURL(
        `/review?flagged_by=${this.args.model.flagging_username}&status=rejected&sort_order=created_at`
      );

      falseNegatives.href = getURL(
        `/review?status=approved&sort_order=created_at&additional_filters={"ai_spam_false_negative":true}&order=created&score_type=${this.args.model.spam_score_type}`
      );
    }
    return [
      {
        label: i18n("discourse_ai.spam.scanned_count"),
        value: this.stats.scanned_count,
      },
      detected,
      falsePositives,
      falseNegatives,
    ];
  }

  <template>
    <div class="ai-spam">
      <section class="ai-spam__settings">
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.spam.title"}}
          @descriptionLabel={{i18n "discourse_ai.spam.spam_description"}}
        />

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
          {{#if this.availableLLMs.length}}
            <ComboBox
              @value={{this.selectedLLM}}
              @content={{this.availableLLMs}}
              @onChange={{this.updateLLM}}
              class="ai-spam__llm-selector"
            />
          {{else}}
            <span class="ai-spam__llm-placeholder">
              <LinkTo @route="adminPlugins.show.discourse-ai-llms.index">
                {{i18n "discourse_ai.spam.no_llms"}}
              </LinkTo>
            </span>
          {{/if}}
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
            @label="discourse_ai.spam.save_button"
            class="ai-spam__instructions-save btn-primary"
          />
          <DButton
            @action={{this.showTestModal}}
            @label="discourse_ai.spam.test_button"
            class="btn-default"
          />
        </div>
      </section>

      <AdminConfigAreaCard
        @heading="discourse_ai.spam.last_seven_days"
        class="ai-spam__stats"
      >
        <:content>
          <DStatTiles as |tiles|>
            {{#each this.metrics as |metric|}}
              <tiles.Tile
                @label={{metric.label}}
                @url={{metric.href}}
                @value={{metric.value}}
                @tooltip={{metric.tooltip}}
              />
            {{/each}}
          </DStatTiles>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
}
