import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import avatar from "discourse/helpers/avatar";
import { ajax } from "discourse/lib/ajax";
import i18n from "discourse-common/helpers/i18n";
import Chart from "admin/components/chart";
import ComboBox from "select-kit/components/combo-box";

export default class AiUsage extends Component {
  @service store;
  @tracked startDate = moment().subtract(30, "days").toDate();
  @tracked endDate = new Date();
  @tracked data = this.args.model;
  @tracked selectedFeature;
  @tracked selectedModel;
  @tracked selectedPeriod = "month";
  @tracked isCustomDateActive = false;

  @action
  async fetchData() {
    const response = await ajax("/admin/plugins/discourse-ai/ai-usage.json", {
      data: {
        start_date: moment(this.startDate).format("YYYY-MM-DD"),
        end_date: moment(this.endDate).format("YYYY-MM-DD"),
        feature: this.selectedFeature,
        model: this.selectedModel,
      },
    });
    this.data = response;
  }

  @action
  async onFilterChange() {
    await this.fetchData();
  }

  @action
  onFeatureChanged(value) {
    this.selectedFeature = value;
    this.onFilterChange();
  }

  @action
  onModelChanged(value) {
    this.selectedModel = value;
    this.onFilterChange();
  }

  normalizeTimeSeriesData(data) {
    if (!data?.length) {
      return [];
    }

    const startDate = moment(this.startDate);
    const endDate = moment(this.endDate);
    const normalized = [];
    let interval;
    let format;

    if (this.data.period === "hour") {
      interval = "hour";
      format = "YYYY-MM-DD HH:00:00";
    } else if (this.data.period === "day") {
      interval = "day";
      format = "YYYY-MM-DD";
    } else {
      interval = "month";
      format = "YYYY-MM";
    }
    const dataMap = new Map(
      data.map((d) => [moment(d.period).format(format), d])
    );

    for (
      let m = moment(startDate);
      m.isSameOrBefore(endDate);
      m.add(1, interval)
    ) {
      const dateKey = m.format(format);
      const existingData = dataMap.get(dateKey);

      normalized.push(
        existingData || {
          period: m.format(),
          total_tokens: 0,
          total_cached_tokens: 0,
          total_request_tokens: 0,
          total_response_tokens: 0,
        }
      );
    }

    return normalized;
  }

  get chartConfig() {
    if (!this.data?.data) {
      return;
    }

    const normalizedData = this.normalizeTimeSeriesData(this.data.data);

    const chartEl = document.querySelector(".ai-usage__chart");
    const computedStyle = getComputedStyle(chartEl);

    const colors = {
      response: computedStyle.getPropertyValue("--chart-response-color").trim(),
      request: computedStyle.getPropertyValue("--chart-request-color").trim(),
      cached: computedStyle.getPropertyValue("--chart-cached-color").trim(),
    };

    return {
      type: "bar",
      data: {
        labels: normalizedData.map((row) => {
          const date = moment(row.period);
          if (this.data.period === "hour") {
            return date.format("HH:00");
          } else if (this.data.period === "day") {
            return date.format("DD-MMM");
          } else {
            return date.format("MMM-YY");
          }
        }),
        datasets: [
          {
            label: "Response Tokens",
            data: normalizedData.map((row) => row.total_response_tokens),
            backgroundColor: colors.response,
          },
          {
            label: "Net Request Tokens",
            data: normalizedData.map(
              (row) => row.total_request_tokens - row.total_cached_tokens
            ),
            backgroundColor: colors.request,
          },
          {
            label: "Cached Request Tokens",
            data: normalizedData.map((row) => row.total_cached_tokens),
            backgroundColor: colors.cached,
          },
        ],
      },
      options: {
        responsive: true,
        scales: {
          x: {
            stacked: true,
          },
          y: {
            stacked: true,
            beginAtZero: true,
          },
        },
      },
    };
  }

  get availableFeatures() {
    // when you switch we don't want the list to change
    // only when you switch durations
    this._cachedFeatures =
      this._cachedFeatures ||
      (this.data?.features || []).map((f) => ({
        id: f.feature_name,
        name: f.feature_name,
      }));

    return this._cachedFeatures;
  }

  get availableModels() {
    this._cachedModels =
      this._cachedModels ||
      (this.data?.models || []).map((m) => ({
        id: m.llm,
        name: m.llm,
      }));

    return this._cachedModels;
  }

  get periodOptions() {
    return [
      { id: "day", name: "Last 24 Hours" },
      { id: "week", name: "Last Week" },
      { id: "month", name: "Last Month" },
    ];
  }

  @action
  setPeriodDates(period) {
    const now = moment();

    switch (period) {
      case "day":
        this.startDate = now.clone().subtract(1, "day").toDate();
        this.endDate = now.toDate();
        break;
      case "week":
        this.startDate = now.clone().subtract(7, "days").toDate();
        this.endDate = now.toDate();
        break;
      case "month":
        this.startDate = now.clone().subtract(30, "days").toDate();
        this.endDate = now.toDate();
        break;
    }
  }

  @action
  onPeriodSelect(period) {
    this.selectedPeriod = period;
    this.isCustomDateActive = false;
    this.setPeriodDates(period);
    this.fetchData();
  }

  @action
  onCustomDateClick() {
    this.isCustomDateActive = !this.isCustomDateActive;
    if (this.isCustomDateActive) {
      this.selectedPeriod = null;
    }
  }

  @action
  onDateChange() {
    this.isCustomDateActive = true;
    this.selectedPeriod = null;
    this.fetchData();
  }

  @action
  onChangeDateRange({ from, to }) {
    this._startDate = from;
    this._endDate = to;
  }

  @action
  onRefreshDateRange() {
    this.startDate = this._startDate;
    this.endDate = this._endDate;
    this.fetchData();
  }

  <template>
    <div class="ai-usage">
      <div class="ai-usage__filters">

        <div class="ai-usage__filters-dates">
          <div class="ai-usage__period-buttons">
            {{#each this.periodOptions as |option|}}
              <button
                type="button"
                class="btn
                  {{if
                    (eq this.selectedPeriod option.id)
                    'btn-primary'
                    'btn-default'
                  }}"
                {{on "click" (fn this.onPeriodSelect option.id)}}
              >
                {{option.name}}
              </button>
            {{/each}}
            <button
              type="button"
              class="btn
                {{if this.isCustomDateActive 'btn-primary' 'btn-default'}}"
              {{on "click" this.onCustomDateClick}}
            >
              Custom...
            </button>
          </div>

          {{#if this.isCustomDateActive}}
            <div class="ai-usage__custom-date-pickers">

              <DateTimeInputRange
                @from={{this.startDate}}
                @to={{this.endDate}}
                @onChange={{this.onChangeDateRange}}
                @showFromTime={{false}}
                @showToTime={{false}}
              />

              <button
                type="button"
                class="btn btn-default"
                {{on "click" this.onRefreshDateRange}}
              >
                {{i18n "refresh"}}
              </button>
            </div>
          {{/if}}
        </div>

        <div class="ai-usage__filters-row">
          <ComboBox
            @value={{this.selectedFeature}}
            @content={{this.availableFeatures}}
            @onChange={{this.onFeatureChanged}}
            @options={{hash none="discourse_ai.usage.all_features"}}
            class="ai-usage__feature-selector"
          />

          <ComboBox
            @value={{this.selectedModel}}
            @content={{this.availableModels}}
            @onChange={{this.onModelChanged}}
            @options={{hash none="discourse_ai.usage.all_models"}}
            class="ai-usage__model-selector"
          />
        </div>

        {{#if this.data}}
          <div class="ai-usage__summary">
            <h3 class="ai-usage__summary-title">
              {{i18n "discourse_ai.usage.summary"}}
            </h3>
            <div class="ai-usage__summary-stats">
              <div class="ai-usage__summary-stat">
                <span class="label">{{i18n
                    "discourse_ai.usage.total_requests"
                  }}</span>
                <span class="value">{{this.data.summary.total_requests}}</span>
              </div>
              <div class="ai-usage__summary-stat">
                <span class="label">{{i18n
                    "discourse_ai.usage.total_tokens"
                  }}</span>
                <span class="value">{{this.data.summary.total_tokens}}</span>
              </div>
              <div class="ai-usage__summary-stat">
                <span class="label">{{i18n
                    "discourse_ai.usage.request_tokens"
                  }}</span>
                <span
                  class="value"
                >{{this.data.summary.total_request_tokens}}</span>
              </div>
              <div class="ai-usage__summary-stat">
                <span class="label">{{i18n
                    "discourse_ai.usage.response_tokens"
                  }}</span>
                <span
                  class="value"
                >{{this.data.summary.total_response_tokens}}</span>
              </div>
              <div class="ai-usage__summary-stat">
                <span class="label">{{i18n
                    "discourse_ai.usage.cached_tokens"
                  }}</span>
                <span
                  class="value"
                >{{this.data.summary.total_cached_tokens}}</span>
              </div>
            </div>
          </div>

          <div class="ai-usage__charts">
            <div class="ai-usage__chart-container">
              <h3 class="ai-usage__chart-title">
                {{i18n "discourse_ai.usage.tokens_over_time"}}
              </h3>
              <Chart
                @chartConfig={{this.chartConfig}}
                class="ai-usage__chart"
              />
            </div>

            <div class="ai-usage__breakdowns">

              <div class="ai-usage__users">
                <h3 class="ai-usage__users-title">
                  {{i18n "discourse_ai.usage.users_breakdown"}}
                </h3>
                <table class="ai-usage__users-table">
                  <thead>
                    <tr>
                      <th>{{i18n "discourse_ai.usage.username"}}</th>
                      <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                      <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {{#each this.data.users as |user|}}
                      <tr class="ai-usage__users-row">
                        <td class="ai-usage__users-cell">
                          <div class="user-info">
                            <LinkTo
                              @route="user"
                              @model={{user.username}}
                              class="username"
                            >
                              {{avatar user imageSize="tiny"}}
                              {{user.username}}
                            </LinkTo>
                          </div></td>
                        <td
                          class="ai-usage__users-cell"
                        >{{user.usage_count}}</td>
                        <td
                          class="ai-usage__users-cell"
                        >{{user.total_tokens}}</td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              </div>

              <div class="ai-usage__features">
                <h3 class="ai-usage__features-title">
                  {{i18n "discourse_ai.usage.features_breakdown"}}
                </h3>
                <table class="ai-usage__features-table">
                  <thead>
                    <tr>
                      <th>{{i18n "discourse_ai.usage.feature"}}</th>
                      <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                      <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {{#each this.data.features as |feature|}}
                      <tr class="ai-usage__features-row">
                        <td
                          class="ai-usage__features-cell"
                        >{{feature.feature_name}}</td>
                        <td
                          class="ai-usage__features-cell"
                        >{{feature.usage_count}}</td>
                        <td
                          class="ai-usage__features-cell"
                        >{{feature.total_tokens}}</td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              </div>

              <div class="ai-usage__models">
                <h3 class="ai-usage__models-title">
                  {{i18n "discourse_ai.usage.models_breakdown"}}
                </h3>
                <table class="ai-usage__models-table">
                  <thead>
                    <tr>
                      <th>{{i18n "discourse_ai.usage.model"}}</th>
                      <th>{{i18n "discourse_ai.usage.usage_count"}}</th>
                      <th>{{i18n "discourse_ai.usage.total_tokens"}}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {{#each this.data.models as |model|}}
                      <tr class="ai-usage__models-row">
                        <td class="ai-usage__models-cell">{{model.llm}}</td>
                        <td
                          class="ai-usage__models-cell"
                        >{{model.usage_count}}</td>
                        <td
                          class="ai-usage__models-cell"
                        >{{model.total_tokens}}</td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
