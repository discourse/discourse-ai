import Component from "@glimmer/component";
import Chart from "admin/components/chart";

export default class AdminReportSentimentAnalysis extends Component {
  get chartConfig() {
    return {
      type: "doughnut",
      data: {
        labels: ["Positive", "Negative", "Neutral"],
        datasets: [
          {
            data: [300, 50, 100],
            backgroundColor: ["#28a745", "#dc3545", "#ffc107"],
          },
        ],
      },
    };
  }

  <template>
    <div>
      <Chart
        @chartConfig={{this.chartConfig}}
        class="admin-report-chart admin-report-doughnut"
      />
    </div>
  </template>
}
