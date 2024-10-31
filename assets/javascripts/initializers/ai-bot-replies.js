import { hbs } from "ember-cli-htmlbars";
import {
  POST_MENU_COPY_LINK_BUTTON_KEY,
  POST_MENU_LIKE_BUTTON_KEY,
  POST_MENU_SHARE_BUTTON_KEY,
  POST_MENU_SHOW_MORE_BUTTON_KEY,
} from "discourse/components/post/menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";
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

const POST_MENU_BUTTONS_POSITION_BEFORE = [
  POST_MENU_LIKE_BUTTON_KEY,
  POST_MENU_COPY_LINK_BUTTON_KEY,
  POST_MENU_SHARE_BUTTON_KEY,
  POST_MENU_SHOW_MORE_BUTTON_KEY,
];

function initializePauseButton(api) {
  const transformerRegistered = api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post } }) => {
      if (isGPTBot(post.user)) {
        dag.add("ai-cancel-gpt", AiCancelStreamingButton, {
          before: POST_MENU_BUTTONS_POSITION_BEFORE,
          after: ["ai-share", "ai-debug"],
        });
      }

      return dag;
    }
  );

  const silencedKey =
    transformerRegistered && "discourse.post-menu-widget-overrides";

  withSilencedDeprecations(silencedKey, () => initializePauseWidgetButton(api));
}

function initializePauseWidgetButton(api) {
  api.addPostMenuButton("cancel-gpt", (post) => {
    if (isGPTBot(post.user)) {
      return {
        icon: "pause",
        action: "cancelStreaming",
        title: "discourse_ai.ai_bot.cancel_streaming",
        className: "btn btn-default cancel-streaming",
        position: "first",
      };
    }
  });

  api.attachWidgetAction("post", "cancelStreaming", function () {
    AiCancelStreamingButton.cancelStreaming(this.model);
  });
}

function initializeDebugButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots || !allowDebug) {
    return;
  }

  const transformerRegistered = api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-debug", AiDebugButton, {
          before: POST_MENU_BUTTONS_POSITION_BEFORE,
          after: "ai-share",
        });
      }

      return dag;
    }
  );

  const silencedKey =
    transformerRegistered && "discourse.post-menu-widget-overrides";

  withSilencedDeprecations(silencedKey, () => initializeDebugWidgetButton(api));
}

function initializeDebugWidgetButton(api) {
  const currentUser = api.getCurrentUser();

  let debugAiResponse = async function ({ post }) {
    const modal = api.container.lookup("service:modal");
    AiDebugButton.debugAiResponse(post, modal);
  };

  api.addPostMenuButton("debugAi", (post) => {
    if (post.topic?.archetype !== "private_message") {
      return;
    }

    if (!isPostFromAiBot(post, currentUser)) {
      return;
    }

    return {
      action: debugAiResponse,
      icon: "info",
      className: "post-action-menu__debug-ai",
      title: "discourse_ai.ai_bot.debug_ai",
      position: "first",
    };
  });
}

function initializeShareButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots) {
    return;
  }

  const transformerRegistered = api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post } }) => {
      if (post.topic?.archetype === "private_message") {
        dag.add("ai-share", AiShareButton, {
          before: POST_MENU_BUTTONS_POSITION_BEFORE,
        });
      }

      return dag;
    }
  );

  const silencedKey =
    transformerRegistered && "discourse.post-menu-widget-overrides";

  withSilencedDeprecations(silencedKey, () => initializeShareWidgetButton(api));
}

function initializeShareWidgetButton(api) {
  const currentUser = api.getCurrentUser();

  let shareAiResponse = async function ({ post, showFeedback }) {
    const modal = api.container.lookup("service:modal");
    AiShareButton.shareAiResponse(post, modal, showFeedback);
  };

  api.addPostMenuButton("share", (post) => {
    // for backwards compat so we don't break if topic is undefined
    if (post.topic?.archetype !== "private_message") {
      return;
    }

    if (!isPostFromAiBot(post, currentUser)) {
      return;
    }

    return {
      action: shareAiResponse,
      icon: "far-copy",
      className: "post-action-menu__share-ai",
      title: "discourse_ai.ai_bot.share",
      position: "first",
    };
  });
}

function initializeShareTopicButton(api) {
  const modal = api.container.lookup("service:modal");
  const currentUser = api.container.lookup("current-user:main");

  api.registerTopicFooterButton({
    id: "share-ai-conversation",
    icon: "share-alt",
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
