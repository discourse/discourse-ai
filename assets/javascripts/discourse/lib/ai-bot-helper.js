import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import ShareFullTopicModal from "../components/modal/share-full-topic-modal";

const MAX_PERSONA_USER_ID = -1200;

export function isPostFromAiBot(post, currentUser) {
  return (
    post.user_id <= MAX_PERSONA_USER_ID ||
    !!currentUser?.ai_enabled_chat_bots?.any(
      (bot) => post.username === bot.username
    )
  );
}

export function showShareConversationModal(modal, topicId) {
  ajax(`/discourse-ai/ai-bot/shared-ai-conversations/preview/${topicId}.json`)
    .then((payload) => {
      modal.show(ShareFullTopicModal, { model: payload });
    })
    .catch(popupAjaxError);
}

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
      topicTitle: i18n("discourse_ai.ai_bot.default_pm_prefix"),
      archetypeId: "private_message",
      draftKey: "new_private_message_ai",
      hasGroups: false,
      warningsDisabled: true,
    },
  });
}
