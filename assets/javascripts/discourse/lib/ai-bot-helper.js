import { ajax } from "discourse/lib/ajax";
import Composer from "discourse/models/composer";
import I18n from "I18n";

export async function ComposeAiBotMessage(targetBot, composer, appEvents) {
  if (appEvents) {
    appEvents.trigger("ai-bot-menu:close");
  }
  let botUsername = await ajax("/discourse-ai/ai-bot/bot-username", {
    data: { username: targetBot },
  }).then((data) => {
    return data.bot_username;
  });

  composer.focusComposer({
    fallbackToNewTopic: true,
    openOpts: {
      action: Composer.PRIVATE_MESSAGE,
      recipients: botUsername,
      topicTitle: I18n.t("discourse_ai.ai_bot.default_pm_prefix"),
      archetypeId: "private_message",
      draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
      hasGroups: false,
      warningsDisabled: true,
    },
  });
}
