import { withPluginApi } from "discourse/lib/plugin-api";
import { cookAsync } from "discourse/lib/text";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadScript from "discourse/lib/load-script";

function isGPTBot(user) {
  return user && user.id === -110;
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
      const post = this.model.postStream.findLoadedPost(data.post_id);

      if (post) {
        if (data.raw) {
          cookAsync(data.raw).then((cooked) => {
            post.set("raw", data.raw);
            post.set("cooked", cooked);

            document
              .querySelector(`#post_${data.post_number}`)
              .classList.add("streaming");

            const cookedElement = document.createElement("div");
            cookedElement.innerHTML = cooked;

            let element = document.querySelector(
              `#post_${data.post_number} .cooked`
            );

            loadScript("/javascripts/diffhtml.min.js").then(() => {
              window.diff.innerHTML(element, cookedElement.innerHTML);
            });
          });
        }
        if (data.done) {
          document
            .querySelector(`#post_${data.post_number}`)
            .classList.remove("streaming");
        }
      }
    },
    subscribe: function () {
      this._super();

      if (
        this.model.isPrivateMessage &&
        this.model.details.allowed_users &&
        this.model.details.allowed_users.filter(isGPTBot).length === 1
      ) {
        this.messageBus.subscribe(
          `discourse-ai/ai-bot/topic/${this.model.id}`,
          this.onAIBotStreamedReply.bind(this)
        );
      }
    },
    unsubscribe: function () {
      this.messageBus.unsubscribe("discourse-ai/ai-bot/topic/");
      this._super();
    },
  });
}

export default {
  name: "discourse-ai-bot-replies",

  initialize(container) {
    const settings = container.lookup("service:site-settings");
    const aiBotEnaled =
      settings.discourse_ai_enabled && settings.ai_bot_enabled;

    if (aiBotEnaled) {
      withPluginApi("1.6.0", initializeAIBotReplies);
    }
  },
};
