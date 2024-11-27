import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
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

  constructor() {
    super(...arguments);
    console.log(this.args.model);
    console.log(this.data);
  }

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

  get chartConfig() {
    console.log("here");
    if (!this.data?.data) {
      return;
    }

    const x = {
      type: "line",
      data: {
        labels: this.data.data.map(pair => pair[0]),
        datasets: [
          {
            label: "Tokens",
            data: this.data.data.map(pair => pair[1]),
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

    console.log(x);
    return x;
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
        </div>

        <div class="ai-usage__filters-period">
          <label class="ai-usage__period-label">
            {{i18n "discourse_ai.usage.period"}}
          </label>
          <ComboBox
            @value={{this.period}}
            @content={{array "hour" "day" "month"}}
            @onChange={{this.onFilterChange}}
            class="ai-usage__period-selector"
          />
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
              <Chart @chartConfig={{this.chartConfig}} class="ai-usage__chart" />
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
