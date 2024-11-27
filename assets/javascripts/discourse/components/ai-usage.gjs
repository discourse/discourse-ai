import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DatePicker from "discourse/components/date-picker";
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
  @tracked period = "day";

  @action
  async fetchData() {
    const response = await ajax("/admin/plugins/discourse-ai/ai-usage.json", {
      data: {
        start_date: moment(this.startDate).format("YYYY-MM-DD"),
        end_date: moment(this.endDate).format("YYYY-MM-DD"),
        feature: this.selectedFeature,
        model: this.selectedModel,
        period: this.period,
      },
    });
    this.data = response;
  }

  @action
  async onDateChange() {
    await this.fetchData();
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

  get chartConfig() {
    if (!this.data?.data) {
      return;
    }

    return {
      type: "line",
      data: {
        labels: this.data.data.map((pair) => pair[0]),
        datasets: [
          {
            label: "Tokens",
            data: this.data.data.map((pair) => pair[1]),
            fill: false,
            borderColor: "rgb(75, 192, 192)",
            tension: 0.1,
          },
        ],
      },
      options: {
        responsive: true,
        scales: {
          y: {
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

  <template>
    <div class="ai-usage">
      <div class="ai-usage__filters">
        <div class="ai-usage__filters-dates">
          <DatePicker
            @value={{this.startDate}}
            @onChange={{this.onDateChange}}
            class="ai-usage__date-picker"
          />
          <DatePicker
            @value={{this.endDate}}
            @onChange={{this.onDateChange}}
            class="ai-usage__date-picker"
          />

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

        </div>

        {{#if this.data}}
          <div class="ai-usage__summary">
            <h3 class="ai-usage__summary-title">
              {{i18n "discourse_ai.usage.summary"}}
            </h3>
            <div class="ai-usage__summary-tokens">
              {{i18n "discourse_ai.usage.total_tokens"}}:
              {{this.data.summary.total_tokens}}
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
