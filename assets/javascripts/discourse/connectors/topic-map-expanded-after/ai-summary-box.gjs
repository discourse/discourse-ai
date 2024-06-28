import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { shortDateNoYear } from "discourse/lib/formatter";
import { cook } from "discourse/lib/text";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";
import AiSummarySkeleton from "../../components/ai-summary-skeleton";

export default class AiSummaryBox extends Component {
  @service siteSettings;
  @service messageBus;
  @service currentUser;
  @tracked summary = "";
  @tracked text = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;
  @tracked regenerated = false;

  @tracked showSummaryBox = false;
  @tracked canCollapseSummary = false;
  @tracked loading = false;

  get generateSummaryTitle() {
    const title = this.canRegenerate
      ? "summary.buttons.regenerate"
      : "summary.buttons.generate";

    return I18n.t(title);
  }

  get generateSummaryIcon() {
    return this.canRegenerate ? "sync" : "discourse-sparkles";
  }

  get outdatedSummaryWarningText() {
    let outdatedText = I18n.t("summary.outdated");

    if (!this.topRepliesSummaryEnabled && this.newPostsSinceSummary > 0) {
      outdatedText += " ";
      outdatedText += I18n.t("summary.outdated_posts", {
        count: this.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  get topRepliesSummaryEnabled() {
    return this.args.outletArgs.postStream.summary;
  }

  @action
  collapse() {
    this.showSummaryBox = false;
    this.canCollapseSummary = false;
  }

  @action
  generateSummary() {
    const topicId = this.args.outletArgs.topic.id;
    this.showSummaryBox = true;

    if (this.text && !this.canRegenerate) {
      this.canCollapseSummary = false;
      return;
    }

    let fetchURL = `/discourse-ai/summarization/t/${topicId}?`;

    if (this.currentUser) {
      fetchURL += `stream=true`;

      if (this.canRegenerate) {
        fetchURL += "&skip_age_check=true";
      }
    }

    this.loading = true;

    return ajax(fetchURL).then((data) => {
      if (!this.currentUser) {
        data.done = true;
        this._updateSummary(data);
      }
    });
  }

  @bind
  subscribe() {
    const channel = `/summaries/topic/${this.args.outletArgs.topic.id}`;
    this.messageBus.subscribe(channel, this._updateSummary);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe("/summaries/topic/*", this._updateSummary);
  }

  @bind
  _updateSummary(update) {
    const topicSummary = update.ai_topic_summary;

    return cook(topicSummary.summarized_text)
      .then((cooked) => {
        this.text = cooked;
        this.loading = false;
      })
      .then(() => {
        if (update.done) {
          this.summarizedOn = shortDateNoYear(topicSummary.summarized_on);
          this.summarizedBy = topicSummary.algorithm;
          this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
          this.outdated = topicSummary.outdated;
          this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
          this.canRegenerate =
            topicSummary.outdated && topicSummary.can_regenerate;
        }
      });
  }

  <template>
    {{#if (or @outletArgs.topic.has_summary @outletArgs.topic.summarizable)}}
      <div class="summarization-buttons">
        {{#if @outletArgs.topic.summarizable}}
          {{#if this.showSummaryBox}}
            <DButton
              @action={{this.collapse}}
              @title="summary.buttons.hide"
              @label="summary.buttons.hide"
              @icon="chevron-up"
              class="btn-primary topic-strategy-summarization"
            />
          {{else}}
            <DButton
              @action={{this.generateSummary}}
              @translatedLabel={{this.generateSummaryTitle}}
              @translatedTitle={{this.generateSummaryTitle}}
              @icon={{this.generateSummaryIcon}}
              @disabled={{this.loading}}
              class="btn-primary topic-strategy-summarization"
            />
          {{/if}}
        {{/if}}

        {{yield}}
      </div>

      <div class="summary-box__container">
        {{#if this.showSummaryBox}}
          <article
            class="summary-box"
            {{didInsert this.subscribe}}
            {{willDestroy this.unsubscribe}}
          >
            {{#if (and this.loading (not this.text))}}
              <AiSummarySkeleton />
            {{else}}
              <div class="generated-summary">{{this.text}}</div>

              {{#if this.summarizedOn}}
                <div class="summarized-on">
                  <p>
                    {{i18n "summary.summarized_on" date=this.summarizedOn}}

                    <DTooltip @placements={{array "top-end"}}>
                      <:trigger>
                        {{dIcon "info-circle"}}
                      </:trigger>
                      <:content>
                        {{i18n "summary.model_used" model=this.summarizedBy}}
                      </:content>
                    </DTooltip>
                  </p>

                  {{#if this.outdated}}
                    <p class="outdated-summary">
                      {{this.outdatedSummaryWarningText}}
                    </p>
                  {{/if}}
                </div>
              {{/if}}
            {{/if}}
          </article>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
