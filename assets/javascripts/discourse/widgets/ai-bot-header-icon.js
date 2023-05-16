import { createWidget } from "discourse/widgets/widget";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

export default createWidget("ai-bot-header-icon", {
  tagName: "li.header-dropdown-toggle.ai-bot-header-icon",
  title: "discourse_ai.ai_bot.shortcut_title",

  services: ["siteSettings"],

  html() {
    const enabledBots = this.siteSettings.ai_bot_enabled_chat_bots
      .split("|")
      .filter(Boolean);

    if (!enabledBots || enabledBots.length === 0) {
      return;
    }

    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<AiBotHeaderIcon />`
      ),
    ];
  },
});
