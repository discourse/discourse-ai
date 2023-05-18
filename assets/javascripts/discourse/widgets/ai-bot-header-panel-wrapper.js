import { createWidget } from "discourse/widgets/widget";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

export default createWidget("ai-bot-header-panel-wrapper", {
  buildAttributes() {
    return { "data-click-outside": true };
  },

  html() {
    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<AiBotHeaderPanel />`
      ),
    ];
  },

  init() {
    this.appEvents.on("ai-bot-menu:close", this, this.clickOutside);
  },

  destroy() {
    this.appEvents.off("ai-bot-menu:close", this, this.clickOutside);
  },

  clickOutside() {
    this.sendWidgetAction("hideAiBotPanel");
  },
});
