import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";
import AiSummarySkeleton from "../../components/ai-summary-skeleton";

const MIN_POST_READ_TIME = 4;

export default class AiSummaryBox extends Component {
  @service siteSettings;

  get summary() {
    return this.args.outletArgs.postStream.topicSummary;
  }

  get generateSummaryTitle() {
    const title = this.summary.canRegenerate
      ? "summary.buttons.regenerate"
      : "summary.buttons.generate";

    return I18n.t(title);
  }

  get generateSummaryIcon() {
    return this.summary.canRegenerate ? "sync" : "discourse-sparkles";
  }

  get outdatedSummaryWarningText() {
    let outdatedText = I18n.t("summary.outdated");

    if (
      !this.topRepliesSummaryEnabled &&
      this.summary.newPostsSinceSummary > 0
    ) {
      outdatedText += " ";
      outdatedText += I18n.t("summary.outdated_posts", {
        count: this.summary.newPostsSinceSummary,
      });
    }

    return outdatedText;
  }

  get topRepliesSummaryEnabled() {
    return this.args.outletArgs.postStream.summary;
  }

  get topRepliesSummaryInfo() {
    if (this.topRepliesSummaryEnabled) {
      return I18n.t("summary.enabled_description");
    }

    const wordCount = this.args.outletArgs.topic.word_count;
    if (wordCount && this.siteSettings.read_time_word_count > 0) {
      const readingTime = Math.ceil(
        Math.max(
          wordCount / this.siteSettings.read_time_word_count,
          (this.args.outletArgs.topic.posts_count * MIN_POST_READ_TIME) / 60
        )
      );
      return I18n.messageFormat("summary.description_time_MF", {
        replyCount: this.args.outletArgs.topic.replyCount,
        readingTime,
      });
    }
    return I18n.t("summary.description", {
      count: this.args.outletArgs.topic.replyCount,
    });
  }

  get topRepliesTitle() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return I18n.t("summary.short_title");
  }

  get topRepliesLabel() {
    const label = this.topRepliesSummaryEnabled
      ? "summary.disable"
      : "summary.enable";

    return I18n.t(label);
  }

  get topRepliesIcon() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return "layer-group";
  }

  <template>
    {{#if (or @outletArgs.topic.has_summary @outletArgs.topic.summarizable)}}
      <section class="information toggle-summary">
        <div class="summary-box__container">
          {{#if @outletArgs.topic.has_summary}}
            <p>{{htmlSafe this.topRepliesSummaryInfo}}</p>
          {{/if}}
          <div class="summarization-buttons">
            {{#if @outletArgs.topic.summarizable}}
              {{#if this.summary.showSummaryBox}}
                <DButton
                  @action={{@outletArgs.collapseSummary}}
                  @title="summary.buttons.hide"
                  @label="summary.buttons.hide"
                  @icon="chevron-up"
                  class="btn-primary topic-strategy-summarization"
                />
              {{else}}
                <DButton
                  @action={{@outletArgs.showSummary}}
                  @translatedLabel={{this.generateSummaryTitle}}
                  @translatedTitle={{this.generateSummaryTitle}}
                  @icon={{this.generateSummaryIcon}}
                  @disabled={{this.summary.loading}}
                  class="btn-primary topic-strategy-summarization"
                />
              {{/if}}
            {{/if}}
            {{#if @outletArgs.topic.has_summary}}
              <DButton
                @action={{if
                  @outletArgs.postStream.summary
                  @outletArgs.cancelFilter
                  @outletArgs.showTopReplies
                }}
                @translatedTitle={{this.topRepliesTitle}}
                @translatedLabel={{this.topRepliesLabel}}
                @icon={{this.topRepliesIcon}}
                class="top-replies"
              />
            {{/if}}
          </div>

          {{#if this.summary.showSummaryBox}}
            <article class="summary-box">
              {{#if (and this.summary.loading (not this.summary.text))}}
                <AiSummarySkeleton />
              {{else}}
                <div class="generated-summary">{{this.summary.text}}</div>

                {{#if this.summary.summarizedOn}}
                  <div class="summarized-on">
                    <p>
                      {{i18n
                        "summary.summarized_on"
                        date=this.summary.summarizedOn
                      }}

                      <DTooltip @placements={{array "top-end"}}>
                        <:trigger>
                          {{dIcon "info-circle"}}
                        </:trigger>
                        <:content>
                          {{i18n
                            "summary.model_used"
                            model=this.summary.summarizedBy
                          }}
                        </:content>
                      </DTooltip>
                    </p>

                    {{#if this.summary.outdated}}
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
      </section>
    {{/if}}
  </template>
}
