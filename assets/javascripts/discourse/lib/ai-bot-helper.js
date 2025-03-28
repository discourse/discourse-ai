import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import ShareFullTopicModal from "../components/modal/share-full-topic-modal";

const MAX_PERSONA_USER_ID = -1200;

let enabledChatBotIds;

export function isGPTBot(user) {
  if (!user) {
    return;
  }

  if (!enabledChatBotIds) {
    const currentUser = getOwnerWithFallback(this).lookup(
      "service:current-user"
    );
    enabledChatBotIds = currentUser.ai_enabled_chat_bots.map((bot) => bot.id);
  }

  return enabledChatBotIds.includes(user.id);
}

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
  const draftKey = "new_private_message_ai_" + new Date().getTime();

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
      draftKey,
      hasGroups: false,
      warningsDisabled: true,
    },
  });
}
