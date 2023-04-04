import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class ChatChannelSummary extends Component {
  @tracked sinceHours = null;
  @tracked loading = false;
  @tracked availableSummaries = {};
  @tracked summary = null;
  sinceOptions = [
    {
      name: I18n.t("discourse_ai.summarization.since", { hours: "1" }),
      value: 1,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { hours: "3" }),
      value: 3,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { hours: "6" }),
      value: 6,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { hours: "12" }),
      value: 12,
    },
    {
      name: I18n.t("discourse_ai.summarization.since", { hours: "24" }),
      value: 24,
    },
  ];

  get modalTitle() {
    return I18n.t("discourse_ai.summarization.modal_title", {
      channel_title: this.args.chatChannel.escapedTitle,
    });
  }

  get canSummarize() {
    return this.sinceHours && !this.loading;
  }

  @action
  summarize(value) {
    this.sinceHours = value;
    this.loading = true;
    const chatChannelId = this.args.chatChannel.id;

    if (this.availableSummaries[this.sinceHours]) {
      this.summary = this.availableSummaries[this.sinceHours];
      this.loading = false;
      return;
    }

    ajax("/discourse-ai/summarization/chat-channel", {
      method: "POST",
      data: { chat_channel_id: chatChannelId, since: this.sinceHours },
    })
      .then((data) => {
        this.availableSummaries[this.sinceHours] = data.summary;
        this.summary = this.availableSummaries[this.sinceHours];
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }
}
