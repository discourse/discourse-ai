import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import PostList from "discourse/components/post-list";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import dIcon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DoughnutChart from "./doughnut-chart";

export default class AdminReportSentimentAnalysis extends Component {
  @tracked selectedChart = null;

  get labels() {
    return ["Positive", "Neutral", "Negative"];
  }

  get colors() {
    return ["#2ecc71", "#95a5a6", "#e74c3c"];
  }

  get transformedData() {
    return this.args.model.data.map((data) => {
      return {
        category_name: data.category_name,
        scores: [
          data.overall_scores.positive,
          data.overall_scores.neutral,
          data.overall_scores.negative,
        ],
        posts: data.posts,
      };
    });
  }

  @action
  showDetails(data) {
    console.log(data);
    this.selectedChart = data;
  }

  sentimentTopScore(post) {
    const { positive_score, neutral_score, negative_score } = post;
    const maxScore = Math.max(positive_score, neutral_score, negative_score);

    if (maxScore === positive_score) {
      return {
        id: "positive",
        text: i18n(
          "discourse_ai.sentiments.sentiment_analysis.score_types.positive"
        ),
        icon: "face-smile",
      };
    } else if (maxScore === neutral_score) {
      return {
        id: "neutral",
        text: i18n(
          "discourse_ai.sentiments.sentiment_analysis.score_types.neutral"
        ),
        icon: "face-meh",
      };
    } else {
      return {
        id: "negative",
        text: i18n(
          "discourse_ai.sentiments.sentiment_analysis.score_types.negative"
        ),
        icon: "face-angry",
      };
    }
  }

  <template>
    {{! TODO add more details about posts on click + tag data }}
    <div class="admin-report-sentiment-analysis">
      {{#each this.transformedData as |data|}}
        <div
          class="admin-report-sentiment-analysis__chart-wrapper"
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
            @labels={{this.labels}}
            @colors={{this.colors}}
            @data={{data.scores}}
            @doughnutTitle={{data.category_name}}
          />
        </div>
      {{/each}}
    </div>

    {{#if this.selectedChart}}
      <div class="admin-report-sentiment-analysis-details">
        <h3 class="admin-report-sentiment-analysis-details__title">
          {{this.selectedChart.category_name}}
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

        <PostList @posts={{this.selectedChart.posts}} @urlPath="postUrl">
          <:abovePostItemExcerpt as |post|>
            {{#let (this.sentimentTopScore post) as |score|}}
              <span
                class="admin-report-sentiment-analysis-details__post-score"
                data-sentiment-score={{score.id}}
              >
                {{dIcon score.icon}}
                {{score.text}}
              </span>
            {{/let}}
          </:abovePostItemExcerpt>
        </PostList>
      </div>
    {{/if}}
  </template>
}
