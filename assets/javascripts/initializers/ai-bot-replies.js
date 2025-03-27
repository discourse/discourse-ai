import { hbs } from "ember-cli-htmlbars";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import AiBotHeaderIcon from "../discourse/components/ai-bot-header-icon";
import AiCancelStreamingButton from "../discourse/components/post-menu/ai-cancel-streaming-button";
import AiDebugButton from "../discourse/components/post-menu/ai-debug-button";
import AiShareButton from "../discourse/components/post-menu/ai-share-button";
import {
  isPostFromAiBot,
  showShareConversationModal,
} from "../discourse/lib/ai-bot-helper";
import { streamPostText } from "../discourse/lib/ai-streamer/progress-handlers";

let enabledChatBotIds = [];
let allowDebug = false;

function isGPTBot(user) {
  return user && enabledChatBotIds.includes(user.id);
}

function attachHeaderIcon(api) {
  api.headerIcons.add("ai", AiBotHeaderIcon);
}

function initializeAIBotReplies(api) {
  initializePauseButton(api);

  api.modifyClass("controller:topic", {
    pluginId: "discourse-ai",

    onAIBotStreamedReply: function (data) {
      streamPostText(this.model.postStream, data);
    },
    subscribe: function () {
      this._super();

      if (
        this.model.isPrivateMessage &&
        this.model.details.allowed_users &&
        this.model.details.allowed_users.filter(isGPTBot).length >= 1
      ) {
        // we attempt to recover the last message in the bus
        // so we subscribe at -2
        this.messageBus.subscribe(
          `discourse-ai/ai-bot/topic/${this.model.id}`,
          this.onAIBotStreamedReply.bind(this),
          -2
        );
      }
    },
    unsubscribe: function () {
      this.messageBus.unsubscribe("discourse-ai/ai-bot/topic/*");
      this._super();
    },
  });
}

function initializePersonaDecorator(api) {
  let topicController = null;
  api.decorateWidget(`poster-name:after`, (dec) => {
    if (!isGPTBot(dec.attrs.user)) {
      return;
    }
    // this is hacky and will need to change
    // trouble is we need to get the model for the topic
    // and it is not available in the decorator
    // long term this will not be a problem once we remove widgets and
    // have a saner structure for our model
    topicController =
      topicController || api.container.lookup("controller:topic");

    return dec.widget.attach("persona-flair", {
      topicController,
    });
  });

  registerWidgetShim(
    "persona-flair",
    "span.persona-flair",
    hbs`{{@data.topicController.model.ai_persona_name}}`
  );
}

function initializePauseButton(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (isGPTBot(post.user)) {
        dag.add("ai-cancel-gpt", AiCancelStreamingButton, {
          before: firstButtonKey,
          after: ["ai-share", "ai-debug"],
        });
      }
    }
  );
}

function initializeDebugButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots || !allowDebug) {
    return;
  }

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-debug", AiDebugButton, {
          before: firstButtonKey,
          after: "ai-share",
        });
      }
    }
  );
}

function initializeShareButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots) {
    return;
  }

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, firstButtonKey } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-share", AiShareButton, {
          before: firstButtonKey,
        });
      }
    }
  );
}

function initializeShareTopicButton(api) {
  const modal = api.container.lookup("service:modal");
  const currentUser = api.container.lookup("service:current-user");

  api.registerTopicFooterButton({
    id: "share-ai-conversation",
    icon: "share-nodes",
    label: "discourse_ai.ai_bot.share_ai_conversation.name",
    title: "discourse_ai.ai_bot.share_ai_conversation.title",
    action() {
      showShareConversationModal(modal, this.topic.id);
    },
    classNames: ["share-ai-conversation-button"],
    dependentKeys: ["topic.ai_persona_name"],
    displayed() {
      return (
        currentUser?.can_share_ai_bot_conversations &&
        this.topic.ai_persona_name
      );
    },
  });
}

export default {
  name: "discourse-ai-bot-replies",

  initialize(container) {
    const user = container.lookup("service:current-user");

    if (user?.ai_enabled_chat_bots) {
      enabledChatBotIds = user.ai_enabled_chat_bots.map((bot) => bot.id);
      allowDebug = user.can_debug_ai_bot_conversations;
      withPluginApi("1.6.0", attachHeaderIcon);
      withPluginApi("1.34.0", initializeAIBotReplies);
      withPluginApi("1.6.0", initializePersonaDecorator);
      withPluginApi("1.34.0", (api) => initializeDebugButton(api, container));
      withPluginApi("1.34.0", (api) => initializeShareButton(api, container));
      withPluginApi("1.22.0", (api) =>
        initializeShareTopicButton(api, container)
      );
    }
  },
};
