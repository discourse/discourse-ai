import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { shortDateNoYear } from "discourse/lib/formatter";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import DTooltip from "float-kit/components/d-tooltip";
import AiSummarySkeleton from "../../components/ai-summary-skeleton";
import streamUpdaterText from "../../lib/ai-streamer/progress-handlers";
import SummaryUpdater from "../../lib/ai-streamer/updaters/summary-updater";

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
  @tracked isStreaming = false;
  oldRaw = null; // used for comparison in SummaryUpdater in lib/ai-streamer/updaters
  finalSummary = null;

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

  resetSummary() {
    this.text = "";
    this.summarizedOn = null;
    this.summarizedBy = null;
    this.newPostsSinceSummary = null;
    this.outdated = false;
    this.canRegenerate = false;
    this.loading = false;
    this._channel = null;
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
  subscribe(unsubscribe, [topicId]) {
    const sameTopicId = this.args.outletArgs.topic.id === topicId;

    if (unsubscribe && this._channel && !sameTopicId) {
      this.unsubscribe();
    }
    const channel = `/discourse-ai/summaries/topic/${this.args.outletArgs.topic.id}`;
    this._channel = channel;
    // we attempt to recover the last message in the bus so we subscrcibe at -2
    this.messageBus.subscribe(channel, this._updateSummary, -2);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(
      "/discourse-ai/summaries/topic/*",
      this._updateSummary
    );
    this.resetSummary();
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
      if (data?.ai_topic_summary?.summarized_text) {
        data.done = true;
        // Our streamer won't display the summary unless the summary box is in the DOM.
        // Wait for the next runloop or cached summaries won't appear.
        next(() => this._updateSummary(data));
      }
    });
  }

  @bind
  _updateSummary(update) {
    const topicSummary = {
      done: update.done,
      raw: update.ai_topic_summary?.summarized_text,
      ...update.ai_topic_summary,
    };
    this.loading = false;

    this.isStreaming = true;
    streamUpdaterText(SummaryUpdater, topicSummary, this);

    if (update.done) {
      this.isStreaming = false;
      this.text = this.finalSummary;
      this.summarizedOn = shortDateNoYear(
        moment(topicSummary.updated_at, "YYYY-MM-DD HH:mm:ss Z")
      );
      this.summarizedBy = topicSummary.algorithm;
      this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
      this.outdated = topicSummary.outdated;
      this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
      this.canRegenerate = topicSummary.outdated && topicSummary.can_regenerate;
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async onClose() {
    await this.dMenu.close();
    this.unsubscribe();
  }

  <template>
    {{#if @outletArgs.topic.summarizable}}
      <div
        class="ai-summarization-button"
        {{didInsert this.subscribe}}
        {{didUpdate this.subscribe @outletArgs.topic.id}}
        {{willDestroy this.unsubscribe}}
      >
        <DMenu
          @onShow={{this.generateSummary}}
          @arrow={{false}}
          @identifier="topic-map__ai-summary"
          @onRegisterApi={{this.onRegisterApi}}
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
          @closeOnClickOutside={{false}}
        >
          <:content>
            <div class="ai-summary-container">
              <header class="ai-summary__header">
                <h3>{{i18n "discourse_ai.summarization.topic.title"}}</h3>
                {{#if this.site.desktopView}}
                  <DButton
                    @title="discourse_ai.summarization.topic.close"
                    @action={{this.onClose}}
                    @icon="times"
                    @class="btn-transparent ai-summary__close"
                  />
                {{/if}}
              </header>

              <article
                class={{concatClass
                  "ai-summary-box"
                  "streamable-content"
                  (if this.isStreaming "streaming")
                }}
              >
                {{#if this.loading}}
                  <AiSummarySkeleton />
                {{else}}
                  <div class="generated-summary cooked">
                    {{this.text}}
                  </div>
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
