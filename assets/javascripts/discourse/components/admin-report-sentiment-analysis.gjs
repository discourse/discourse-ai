import Component from "@glimmer/component";
import Chart from "admin/components/chart";

export default class AdminReportSentimentAnalysis extends Component {
  get chartConfig() {
    return {
      type: "doughnut",
      data: {
        labels: ["Positive", "Neutral", "Negative"],
        datasets: [
          {
            data: [300, 50, 100],
            backgroundColor: ["#2ecc71", "#95a5a6", "#e74c3c"],
          },
        ],
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: "bottom",
          },
        },
      },
      plugins: [
        {
          id: "centerText",
          afterDraw: function (chart) {
            const cssVarColor =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--primary"
              ) || "#000";
            const cssFontSize =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-down-2"
              ) || "1.3em";
            const cssFontFamily =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-family"
              ) || "sans-serif";

            const { ctx, chartArea } = chart;
            const centerX = (chartArea.left + chartArea.right) / 2;
            const centerY = (chartArea.top + chartArea.bottom) / 2;

            ctx.restore();
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillStyle = cssVarColor.trim();
            ctx.font = `${cssFontSize.trim()} ${cssFontFamily.trim()}`;

            // TODO: populate with actual tag / category title
            ctx.fillText("member-experience", centerX, centerY);
            ctx.save();
          },
        },
      ],
    };
  }

  <template>
    {{! TODO each-loop based on data, display doughnut component }}
    <div class="admin-report-sentiment-analysis">
      <Chart @chartConfig={{this.chartConfig}} class="admin-report-doughnut" />
      <Chart @chartConfig={{this.chartConfig}} class="admin-report-doughnut" />
      <Chart @chartConfig={{this.chartConfig}} class="admin-report-doughnut" />
      <Chart @chartConfig={{this.chartConfig}} class="admin-report-doughnut" />
      <Chart @chartConfig={{this.chartConfig}} class="admin-report-doughnut" />
    </div>
  </template>
}
