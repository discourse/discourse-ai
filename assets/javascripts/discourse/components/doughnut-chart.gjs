import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { isDevelopment } from "discourse/lib/environment";
import Chart from "admin/components/chart";

export default class DoughnutChart extends Component {
  @tracked canvasSize = null;

  calculateRadius(postCount) {
    const minPosts = 0;
    const maxPosts = 100;
    const minRadius = 30;
    const maxRadius = 100;
    const clampedPostCount = Math.min(Math.max(postCount, minPosts), maxPosts);
    return (
      minRadius +
      ((clampedPostCount - minPosts) / (maxPosts - minPosts)) *
        (maxRadius - minRadius)
    );
  }

  getRadius() {
    if (this.args.radius) {
      return this.args.radius;
    } else if (isDevelopment()) {
      return this.calculateRadius(Math.floor(Math.random() * (100 + 1)));
    } else {
      return this.calculateRadius(this.args.totalScore);
    }
  }

  get config() {
    const totalScore = this.args.totalScore || "";
    const skipCanvasResize = this.args.skipCanvasResize || false;
    const radius = this.getRadius();

    const paddingTop = 30;
    const paddingBottom = 0;
    const canvasSize = 2 * radius + paddingTop + paddingBottom;
    this.canvasSize = canvasSize;

    return {
      type: "doughnut",
      data: {
        labels: this.args.labels,
        datasets: [
          {
            data: this.args.data,
            backgroundColor: this.args.colors,
            cutout: "70%",
            radius,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            top: paddingTop,
            left: 0,
            right: 0,
            bottom: 0,
          },
        },
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
        {
          id: "resizeCanvas",
          afterDraw: function (chart) {
            if (skipCanvasResize) {
              return;
            }
            const size = `${canvasSize}px`;
            chart.canvas.style.width = size;
            chart.canvas.style.height = size;

            chart.resize();
          },
        },
      ],
    };
  }

  <template>
    {{#if this.config}}
      <h3
        class="doughnut-chart-title"
        style={{htmlSafe (concat "max-width: " this.canvasSize "px")}}
      >{{@doughnutTitle}}</h3>
      <Chart @chartConfig={{this.config}} class="admin-report-doughnut" />
    {{/if}}
  </template>
}
