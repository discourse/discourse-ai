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
import DMenu from "float-kit/components/d-menu";
import DTooltip from "float-kit/components/d-tooltip";
import AiSummarySkeleton from "../../components/ai-summary-skeleton";

export default class AiSummaryBox extends Component {
  @service siteSettings;
  @service messageBus;
  @service currentUser;
  @service site;

  @tracked text = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;
  @tracked loading = false;

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

  get topicId() {
    return this.args.outletArgs.topic.id;
  }

  get baseSummarizationURL() {
    return `/discourse-ai/summarization/t/${this.topicId}`;
  }

  @bind
  subscribe() {
    const channel = `/discourse-ai/summaries/topic/${this.args.outletArgs.topic.id}`;
    this.messageBus.subscribe(channel, this._updateSummary);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(
      "/discourse-ai/summaries/topic/*",
      this._updateSummary
    );
  }

  @action
  generateSummary() {
    let fetchURL = this.baseSummarizationURL;

    if (this.currentUser) {
      fetchURL += `?stream=true`;
    }

    return this._requestSummary(fetchURL);
  }

  @action
  regenerateSummary() {
    let fetchURL = this.baseSummarizationURL;

    if (this.currentUser) {
      fetchURL += `?stream=true`;

      if (this.canRegenerate) {
        fetchURL += "&skip_age_check=true";
      }
    }

    return this._requestSummary(fetchURL);
  }

  @action
  _requestSummary(url) {
    if (this.loading || (this.text && !this.canRegenerate)) {
      return;
    }

    this.loading = true;
    this.summarizedOn = null;

    return ajax(url).then((data) => {
      if (!this.currentUser) {
        data.done = true;
        this._updateSummary(data);
      }
    });
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
          this.summarizedOn = shortDateNoYear(topicSummary.updated_at);
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
    {{#if @outletArgs.topic.summarizable}}
      <div
        class="ai-summarization-button"
        {{didInsert this.subscribe}}
        {{willDestroy this.unsubscribe}}
      >
        <DMenu
          @onShow={{this.generateSummary}}
          @arrow={{true}}
          @identifier="topic-map__ai-summary"
          @interactive={{true}}
          @triggers="click"
          @placement="left"
          @modalForMobile={{true}}
          @groupIdentifier="topic-map"
          @inline={{true}}
          @label={{i18n "summary.buttons.generate"}}
          @title={{i18n "summary.buttons.generate"}}
          @icon="discourse-sparkles"
          @triggerClass="ai-topic-summarization"
        >
          <:content>
            <div class="ai-summary-container">
              <header class="ai-summary__header">
                <h3>{{i18n "discourse_ai.summarization.topic.title"}}</h3>
                {{#if this.site.desktopView}}
                  <DButton
                    @title="discourse_ai.summarization.topic.close"
                    @action={{this.unsubscribe}}
                    @icon="times"
                    @class="btn-transparent ai-summary__close"
                  />
                {{/if}}
              </header>

              <article class="ai-summary-box">
                {{#if this.loading}}
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
                            {{i18n
                              "summary.model_used"
                              model=this.summarizedBy
                            }}
                          </:content>
                        </DTooltip>
                      </p>
                      <div class="outdated-summary">
                        {{#if this.outdated}}
                          <p>{{this.outdatedSummaryWarningText}}</p>
                        {{/if}}
                        {{#if this.canRegenerate}}
                          <DButton
                            @label="summary.buttons.regenerate"
                            @title="summary.buttons.regenerate"
                            @action={{this.regenerateSummary}}
                            @icon="sync"
                          />
                        {{/if}}
                      </div>
                    </div>
                  {{/if}}
                {{/if}}
              </article>
            </div>
          </:content>
        </DMenu>
      </div>
    {{/if}}
  </template>
}
