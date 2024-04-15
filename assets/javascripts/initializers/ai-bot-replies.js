import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import DebugAiModal from "../discourse/components/modal/debug-ai-modal";
import ShareModal from "../discourse/components/modal/share-modal";
import streamText from "../discourse/lib/ai-streamer";
import copyConversation from "../discourse/lib/copy-conversation";
const AUTO_COPY_THRESHOLD = 4;
import AiBotHeaderIcon from "../discourse/components/ai-bot-header-icon";
import { showShareConversationModal } from "../discourse/lib/ai-bot-helper";

let enabledChatBotIds = [];
let allowDebug = false;
function isGPTBot(user) {
  return user && enabledChatBotIds.includes(user.id);
}

function attachHeaderIcon(api) {
  api.headerIcons.add("ai", AiBotHeaderIcon);
}

function initializeAIBotReplies(api) {
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
    ajax(`/discourse-ai/ai-bot/post/${this.model.id}/stop-streaming`, {
      type: "POST",
    })
      .then(() => {
        document
          .querySelector(`#post_${this.model.post_number}`)
          .classList.remove("streaming");
      })
      .catch(popupAjaxError);
  });

  api.modifyClass("controller:topic", {
    pluginId: "discourse-ai",

    onAIBotStreamedReply: function (data) {
      streamText(this.model.postStream, data);
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

const MAX_PERSONA_USER_ID = -1200;

function initializeDebugButton(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser || !currentUser.ai_enabled_chat_bots || !allowDebug) {
    return;
  }

  let debugAiResponse = async function ({ post }) {
    const modal = api.container.lookup("service:modal");
    // message is attached to previous post so look it up...
    const postStream = post.topic.get("postStream");

    let previousPost;

    for (let i = 0; i < postStream.posts.length; i++) {
      let p = postStream.posts[i];
      if (p.id === post.id) {
        break;
      }
      previousPost = p;
    }

    modal.show(DebugAiModal, { model: previousPost });
  };

  api.addPostMenuButton("debugAi", (post) => {
    if (post.topic?.archetype !== "private_message") {
      return;
    }

    if (
      !currentUser.ai_enabled_chat_bots.any(
        (bot) => post.username === bot.username
      )
    ) {
      // special handling for personas (persona bot users start at ID -1200 and go down)
      if (post.user_id > MAX_PERSONA_USER_ID) {
        return;
      }
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

  let shareAiResponse = async function ({ post, showFeedback }) {
    if (post.post_number <= AUTO_COPY_THRESHOLD) {
      await copyConversation(post.topic, 1, post.post_number);
      showFeedback("discourse_ai.ai_bot.conversation_shared");
    } else {
      const modal = api.container.lookup("service:modal");
      modal.show(ShareModal, { model: post });
    }
  };

  api.addPostMenuButton("share", (post) => {
    // for backwards compat so we don't break if topic is undefined
    if (post.topic?.archetype !== "private_message") {
      return;
    }

    if (
      !currentUser.ai_enabled_chat_bots.any(
        (bot) => post.username === bot.username
      )
    ) {
      // special handling for personas (persona bot users start at ID -1200 and go down)
      if (post.user_id > MAX_PERSONA_USER_ID) {
        return;
      }
    }

    return {
      action: shareAiResponse,
      icon: "share",
      className: "post-action-menu__share",
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
      withPluginApi("1.6.0", initializeAIBotReplies);
      withPluginApi("1.6.0", initializePersonaDecorator);
      withPluginApi("1.22.0", (api) => initializeDebugButton(api, container));
      withPluginApi("1.22.0", (api) => initializeShareButton(api, container));
      withPluginApi("1.22.0", (api) =>
        initializeShareTopicButton(api, container)
      );
    }
  },
};
