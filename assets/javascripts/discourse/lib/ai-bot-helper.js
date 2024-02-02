import Composer from "discourse/models/composer";
import I18n from "I18n";

export function composeAiBotMessage(targetBot, composer) {
  const currentUser = composer.currentUser;

  let botUsername = currentUser.ai_enabled_chat_bots.find(
    (bot) => bot.model_name === targetBot
  ).username;

  composer.focusComposer({
    fallbackToNewTopic: true,
    openOpts: {
      action: Composer.PRIVATE_MESSAGE,
      recipients: botUsername,
      topicTitle: I18n.t("discourse_ai.ai_bot.default_pm_prefix"),
      archetypeId: "private_message",
      draftKey: "private_message_ai",
      hasGroups: false,
      warningsDisabled: true,
      skipDraftCheck: true,
    },
  });
}
