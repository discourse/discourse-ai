import Component from "@glimmer/component";
import Chart from "admin/components/chart";

export default class DoughnutChart extends Component {
  get config() {
    const totalScore = this.args.totalScore || "";

    return {
      type: "doughnut",
      data: {
        labels: this.args.labels,
        datasets: [
          {
            data: this.args.data,
            backgroundColor: this.args.colors,
          },
        ],
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: this.args.legendPosition || "bottom",
          },
        },
      },
      plugins: [
        {
          id: "centerText",
          afterDraw: function (chart) {
            const cssVarColor =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--primary-high"
              ) || "#000";
            const cssFontSize =
              getComputedStyle(document.documentElement).getPropertyValue(
                "--font-up-4"
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
            ctx.font = `bold ${cssFontSize.trim()} ${cssFontFamily.trim()}`;

            ctx.fillText(totalScore, centerX, centerY);
            ctx.save();
          },
        },
      ],
    };
  }

  <template>
    {{#if this.config}}
      <h3 class="doughnut-chart-title">{{@doughnutTitle}}</h3>
      <Chart @chartConfig={{this.config}} class="admin-report-doughnut" />
    {{/if}}
  </template>
}
