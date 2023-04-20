import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";

function initializeChatChannelSummary(api) {
  const chat = api.container.lookup("service:chat");
  if (chat) {
    api.registerChatComposerButton?.({
      translatedLabel: "discourse_ai.summarization.title",
      id: "chat_channel_summary",
      icon: "discourse-sparkles",
      action: "showChannelSummary",
      position: "dropdown",
    });

    api.modifyClass("component:chat-composer", {
      pluginId: "discourse-ai",

      @action
      showChannelSummary() {
        showModal("ai-summary").setProperties({
          targetId: this.chatChannel.id,
          targetType: "chat_channel",
          allowTimeframe: true,
        });
      },
    });
  }
}

export default {
  name: "discourse_ai-chat_channel_summary",

  initialize(container) {
    const settings = container.lookup("site-settings:main");

    const summarizationEnabled =
      settings.discourse_ai_enabled && settings.ai_summarization_enabled;

    if (summarizationEnabled) {
      withPluginApi("1.6.0", initializeChatChannelSummary);
    }
  },
};
