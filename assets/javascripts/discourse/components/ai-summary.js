import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class AiSummary extends Component {
  @tracked sinceHours = null;
  @tracked loading = false;
  @tracked availableSummaries = {};
  @tracked summary = null;
  sinceOptions = [
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 1 }),
      value: 1,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 3 }),
      value: 3,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 6 }),
      value: 6,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 12 }),
      value: 12,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 24 }),
      value: 24,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 72 }),
      value: 72,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { count: 168 }),
      value: 168,
    },
  ];

  get canSummarize() {
    return (!this.args.allowTimeframe || this.sinceHours) && !this.loading;
  }

  @action
  summarize(value) {
    this.loading = true;
    const attrs = {
      target_id: this.args.targetId,
      target_type: this.args.targetType,
    };

    if (this.args.allowTimeframe) {
      this.sinceHours = value;

      if (this.availableSummaries[this.sinceHours]) {
        this.summary = this.availableSummaries[this.sinceHours];
        this.loading = false;
        return;
      } else {
        attrs.since = this.sinceHours;
      }
    }

    ajax("/discourse-ai/summarization/summary", {
      method: "POST",
      data: attrs,
    })
      .then((data) => {
        if (this.args.allowTimeframe) {
          this.availableSummaries[this.sinceHours] = data.summary;
          this.summary = this.availableSummaries[this.sinceHours];
        } else {
          this.summary = data.summary;
        }
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }
}
