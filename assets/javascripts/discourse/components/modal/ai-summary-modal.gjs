import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import htmlClass from "discourse/helpers/html-class";
import { ajax } from "discourse/lib/ajax";
import { shortDateNoYear } from "discourse/lib/formatter";
import dIcon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import AiSummarySkeleton from "../../components/ai-summary-skeleton";

const STREAMED_TEXT_SPEED = 15;

export default class AiSummaryModal extends Component {
  @service siteSettings;
  @service messageBus;
  @service currentUser;
  @service site;
  @service modal;

  @tracked text = "";
  @tracked summarizedOn = null;
  @tracked summarizedBy = null;
  @tracked newPostsSinceSummary = null;
  @tracked outdated = false;
  @tracked canRegenerate = false;
  @tracked loading = false;
  @tracked isStreaming = false;
  @tracked streamedText = "";
  @tracked currentIndex = 0;
  typingTimer = null;
  streamedTextLength = 0;

  get outdatedSummaryWarningText() {
    let outdatedText = i18n("summary.outdated");

    if (!this.topRepliesSummaryEnabled && this.newPostsSinceSummary > 0) {
      outdatedText += " ";
      outdatedText += i18n("summary.outdated_posts", {
        count: this.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  resetSummary() {
    this.streamedText = "";
    this.currentIndex = 0;
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
    return this.args.model.postStream.summary;
  }

  get topicId() {
    return this.args.model.topic.id;
  }

  get baseSummarizationURL() {
    return `/discourse-ai/summarization/t/${this.topicId}`;
  }

  @bind
  subscribe() {
    const channel = `/discourse-ai/summaries/topic/${this.args.model.topic.id}`;
    this._channel = channel;
    this.messageBus.subscribe(channel, this._updateSummary);
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

    // ensure summary is reset before requesting a new one:
    this.resetSummary();
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
        this._updateSummary(data);
      }
    });
  }

  typeCharacter() {
    if (this.streamedTextLength < this.text.length) {
      this.streamedText += this.text.charAt(this.streamedTextLength);
      this.streamedTextLength++;

      this.typingTimer = later(this, this.typeCharacter, STREAMED_TEXT_SPEED);
    } else {
      this.typingTimer = null;
    }
  }

  onTextUpdate() {
    // Reset only if there’s a new summary to process
    if (this.typingTimer) {
      cancel(this.typingTimer);
    }

    this.typeCharacter();
  }

  @bind
  async _updateSummary(update) {
    const topicSummary = {
      done: update.done,
      raw: update.ai_topic_summary?.summarized_text,
      ...update.ai_topic_summary,
    };
    const newText = topicSummary.raw || "";
    this.loading = false;

    if (update.done) {
      this.text = newText;
      this.streamedText = newText;
      this.displayedTextLength = newText.length;
      this.isStreaming = false;
      this.summarizedOn = shortDateNoYear(
        moment(topicSummary.updated_at, "YYYY-MM-DD HH:mm:ss Z")
      );
      this.summarizedBy = topicSummary.algorithm;
      this.newPostsSinceSummary = topicSummary.new_posts_since_summary;
      this.outdated = topicSummary.outdated;
      this.canRegenerate = topicSummary.outdated && topicSummary.can_regenerate;

      // Clear pending animations
      if (this.typingTimer) {
        cancel(this.typingTimer);
        this.typingTimer = null;
      }
    } else if (newText.length > this.text.length) {
      this.text = newText;
      this.isStreaming = true;
      this.onTextUpdate();
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  handleClose() {
    this.modal.triggerElement = null; // prevent refocus of trigger, which changes scroll position
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.summarization.topic.title"}}
      @closeModal={{this.handleClose}}
      @bodyClass="ai-summary-modal__body"
      class="ai-summary-modal"
      {{didInsert this.subscribe @model.topic.id}}
      {{didUpdate this.subscribe @model.topic.id}}
      {{willDestroy this.unsubscribe}}
      @hideFooter={{not this.summarizedOn}}
    >
      <:body>
        {{htmlClass "scrollable-modal"}}
        <div class="ai-summary-container" {{didInsert this.generateSummary}}>
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
                <CookText @rawText={{this.streamedText}} />
              </div>
            {{/if}}
          </article>
        </div>
      </:body>
      <:footer>
        <p class="summarized-on">
          {{i18n "summary.summarized_on" date=this.summarizedOn}}
          <DTooltip @placements={{array "top-end"}}>
            <:trigger>
              {{dIcon "circle-info"}}
            </:trigger>
            <:content>
              {{i18n "summary.model_used" model=this.summarizedBy}}
            </:content>
          </DTooltip>
        </p>
        {{#if this.outdated}}
          <p class="summary-outdated">{{this.outdatedSummaryWarningText}}</p>
        {{/if}}
        {{#if this.canRegenerate}}
          <DButton
            @label="summary.buttons.regenerate"
            @title="summary.buttons.regenerate"
            @action={{this.regenerateSummary}}
            @icon="arrows-rotate"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
