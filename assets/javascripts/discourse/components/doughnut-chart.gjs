import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { isDevelopment } from "discourse/lib/environment";
import Chart from "admin/components/chart";

export default class DoughnutChart extends Component {
  @tracked canvasSize = null;

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
            cutout: "50%",
            radius: 100,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: this.args.displayLegend || false,
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
