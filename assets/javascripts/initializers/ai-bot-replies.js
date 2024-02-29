import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
import { composeAiBotMessage } from "discourse/plugins/discourse-ai/discourse/lib/ai-bot-helper";
import ShareModal from "../discourse/components/modal/share-modal";
import streamText from "../discourse/lib/ai-streamer";
import copyConversation from "../discourse/lib/copy-conversation";

const AUTO_COPY_THRESHOLD = 4;

let enabledChatBotIds = [];
function isGPTBot(user) {
  return user && enabledChatBotIds.includes(user.id);
}

function attachHeaderIcon(api) {
  const settings = api.container.lookup("service:site-settings");

  const enabledBots = settings.ai_bot_add_to_header
    ? settings.ai_bot_enabled_chat_bots.split("|").filter(Boolean)
    : [];
  if (enabledBots.length > 0) {
    api.attachWidgetAction("header", "showAiBotPanel", function () {
      this.state.botSelectorVisible = true;
    });

    api.attachWidgetAction("header", "hideAiBotPanel", function () {
      this.state.botSelectorVisible = false;
    });

    api.decorateWidget("header-icons:before", (helper) => {
      return helper.attach("header-dropdown", {
        title: "discourse_ai.ai_bot.shortcut_title",
        icon: "robot",
        action: "clickStartAiBotChat",
        active: false,
        classNames: ["ai-bot-button"],
      });
    });

    if (enabledBots.length === 1) {
      api.attachWidgetAction("header", "clickStartAiBotChat", function () {
        composeAiBotMessage(
          enabledBots[0],
          api.container.lookup("service:composer")
        );
      });
    } else {
      api.attachWidgetAction("header", "clickStartAiBotChat", function () {
        this.sendWidgetAction("showAiBotPanel");
      });
    }

    api.addHeaderPanel(
      "ai-bot-header-panel-wrapper",
      "botSelectorVisible",
      function () {
        return {};
      }
    );
  }
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

  const modal = api.container.lookup("service:modal");
}

export default {
  name: "discourse-ai-bot-replies",

  initialize(container) {
    const settings = container.lookup("service:site-settings");
    const user = container.lookup("service:current-user");

    if (user?.ai_enabled_chat_bots) {
      enabledChatBotIds = user.ai_enabled_chat_bots.map((bot) => bot.id);
      if (settings.ai_bot_add_to_header) {
        withPluginApi("1.6.0", attachHeaderIcon);
      }
      withPluginApi("1.6.0", initializeAIBotReplies);
      withPluginApi("1.6.0", initializePersonaDecorator);
      withPluginApi("1.22.0", (api) => initializeShareButton(api, container));
    }
  },
};
