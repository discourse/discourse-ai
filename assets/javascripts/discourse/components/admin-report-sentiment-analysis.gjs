import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import PostList from "discourse/components/post-list";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Post from "discourse/models/post";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";
import DoughnutChart from "discourse/plugins/discourse-ai/discourse/components/doughtnut-chart";

export default class AdminReportSentimentAnalysis extends Component {
  @tracked selectedChart = null;
  @tracked posts = null;

  get colors() {
    return ["#2ecc71", "#95a5a6", "#e74c3c"];
  }

  calculateNeutralScore(data) {
    return data.total_count - (data.positive_count + data.negative_count);
  }

  get currentGroupFilter() {
    return this.args.model.available_filters.find(
      (filter) => filter.id === "group_by"
    ).default;
  }

  get currentSortFilter() {
    return this.args.model.available_filters.find(
      (filter) => filter.id === "sort_by"
    ).default;
  }

  get transformedData() {
    return this.args.model.data.map((data) => {
      return {
        title: data.category_name || data.tag_name,
        scores: [
          data.positive_count,
          this.calculateNeutralScore(data),
          data.negative_count,
        ],
        total_score: data.total_count,
      };
    });
  }

  @action
  async showDetails(data) {
    this.selectedChart = data;
    try {
      const posts = await ajax(`/discourse-ai/sentiment/posts`, {
        data: {
          group_by: this.currentGroupFilter,
          group_value: data.title,
          start_date: this.args.model.start_date,
          end_date: this.args.model.end_date,
        },
      });

      this.posts = posts.map((post) => Post.create(post));
    } catch (e) {
      popupAjaxError(e);
    }
  }

  sentimentMapping(sentiment) {
    switch (sentiment) {
      case "positive":
        return {
          id: "positive",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.score_types.positive"
          ),
          icon: "face-smile",
        };
      case "neutral":
        return {
          id: "neutral",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.score_types.neutral"
          ),
          icon: "face-meh",
        };
      case "negative":
        return {
          id: "negative",
          text: i18n(
            "discourse_ai.sentiments.sentiment_analysis.score_types.negative"
          ),
          icon: "face-angry",
        };
    }
  }

  doughnutTitle(data) {
    if (data?.total_score) {
      return `${data.title} (${data.total_score})`;
    } else {
      return data.title;
    }
  }

  <template>
    <div class="admin-report-sentiment-analysis">
      {{#each this.transformedData as |data|}}
        <div
          class="admin-report-sentiment-analysis__chart-wrapper"
          role="button"
          {{on "click" (fn this.showDetails data)}}
          {{closeOnClickOutside
            (fn (mut this.selectedChart) null)
            (hash
              targetSelector=".admin-report-sentiment-analysis-details"
              secondaryTargetSelector=".admin-report-sentiment-analysis"
            )
          }}
        >
          <DoughnutChart
            @labels={{@model.labels}}
            @colors={{this.colors}}
            @data={{data.scores}}
            @doughnutTitle={{this.doughnutTitle data}}
          />
        </div>
      {{/each}}
    </div>

    {{#if this.selectedChart}}
      <div class="admin-report-sentiment-analysis-details">
        <h3 class="admin-report-sentiment-analysis-details__title">
          {{this.selectedChart.title}}
        </h3>

        <ul class="admin-report-sentiment-analysis-details__scores">
          <li>
            {{dIcon "face-smile" style="color: #2ecc71"}}
            {{i18n
              "discourse_ai.sentiments.sentiment_analysis.score_types.positive"
            }}:
            {{get this.selectedChart.scores 0}}</li>
          <li>
            {{dIcon "face-meh"}}
            {{i18n
              "discourse_ai.sentiments.sentiment_analysis.score_types.neutral"
            }}:
            {{get this.selectedChart.scores 1}}</li>
          <li>
            {{dIcon "face-angry"}}
            {{i18n
              "discourse_ai.sentiments.sentiment_analysis.score_types.negative"
            }}:
            {{get this.selectedChart.scores 2}}</li>
        </ul>

        <PostList
          @posts={{this.posts}}
          @urlPath="url"
          @idPath="post_id"
          @titlePath="topic_title"
          @usernamePath="username"
          class="admin-report-sentiment-analysis-details__post-list"
        >
          <:abovePostItemExcerpt as |post|>
            {{#let (this.sentimentMapping post.sentiment) as |sentiment|}}
              <span
                class="admin-report-sentiment-analysis-details__post-score"
                data-sentiment-score={{sentiment.id}}
              >
                {{dIcon sentiment.icon}}
                {{sentiment.text}}
              </span>
            {{/let}}
          </:abovePostItemExcerpt>
        </PostList>
      </div>
    {{/if}}
  </template>
}
