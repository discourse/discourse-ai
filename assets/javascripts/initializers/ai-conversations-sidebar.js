import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AiBotSidebarNewConversation from "../discourse/components/ai-bot-sidebar-new-conversation";
import { isPostFromAiBot } from "../discourse/lib/ai-bot-helper";
import { AI_CONVERSATIONS_PANEL } from "../discourse/services/ai-conversations-sidebar-manager";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi((api) => {
      const siteSettings = api.container.lookup("service:site-settings");
      if (!siteSettings.ai_enable_experimental_bot_ux) {
        return;
      }

      const currentUser = api.container.lookup("service:current-user");
      if (!currentUser) {
        return;
      }

      const aiConversationsSidebarManager = api.container.lookup(
        "service:ai-conversations-sidebar-manager"
      );
      const appEvents = api.container.lookup("service:app-events");
      const messageBus = api.container.lookup("service:message-bus");

      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class AiConversationsSidebarPanel extends BaseCustomSidebarPanel {
            key = AI_CONVERSATIONS_PANEL;
            hidden = true;
            displayHeader = true;
            expandActiveSection = true;
          }
      );

      api.renderInOutlet("sidebar-footer-actions", AiBotSidebarNewConversation);
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const AiConversationLink = class extends BaseCustomSidebarSectionLink {
            route = "topic.fromParamsNear";

            constructor(topic) {
              super(...arguments);
              this.topic = topic;
            }

            get name() {
              return this.topic.title;
            }

            get models() {
              return [
                this.topic.slug,
                this.topic.id,
                this.topic.last_read_post_number || 0,
              ];
            }

            get title() {
              return this.topic.title;
            }

            get text() {
              return this.topic.title;
            }

            get classNames() {
              return `ai-conversation-${this.topic.id}`;
            }
          };

          return class extends BaseCustomSidebarSection {
            @tracked links = new TrackedArray();
            @tracked topics = [];
            @tracked hasMore = [];
            page = 0;
            isFetching = false;
            totalTopicsCount = 0;

            constructor() {
              super(...arguments);
              this.fetchMessages();

              appEvents.on("topic:created", this, "addNewMessageToSidebar");
            }

            @bind
            willDestroy() {
              this.removeScrollListener();
              appEvents.on("topic:created", this, "addNewMessageToSidebar");
            }

            get name() {
              return "ai-conversations-history";
            }

            get text() {
              return i18n(
                "discourse_ai.ai_bot.conversations.messages_sidebar_title"
              );
            }

            get sidebarElement() {
              return document.querySelector(
                ".sidebar-wrapper .sidebar-sections"
              );
            }

            addNewMessageToSidebar(topic) {
              this.addNewMessage(topic);
              this.watchForTitleUpdate(topic);
            }

            @bind
            removeScrollListener() {
              const sidebar = this.sidebarElement;
              if (sidebar) {
                sidebar.removeEventListener("scroll", this.scrollHandler);
              }
            }

            @bind
            attachScrollListener() {
              const sidebar = this.sidebarElement;
              if (sidebar) {
                sidebar.addEventListener("scroll", this.scrollHandler);
              }
            }

            @bind
            scrollHandler() {
              const sidebarElement = this.sidebarElement;
              if (!sidebarElement) {
                return;
              }

              const scrollPosition = sidebarElement.scrollTop;
              const scrollHeight = sidebarElement.scrollHeight;
              const clientHeight = sidebarElement.clientHeight;

              // When user has scrolled to bottom with a small threshold
              if (scrollHeight - scrollPosition - clientHeight < 100) {
                if (this.hasMore && !this.isFetching) {
                  this.loadMore();
                }
              }
            }

            async fetchMessages(isLoadingMore = false) {
              if (this.isFetching) {
                return;
              }

              try {
                this.isFetching = true;
                const data = await ajax(
                  "/discourse-ai/ai-bot/conversations.json",
                  {
                    data: { page: this.page, per_page: 40 },
                  }
                );

                if (isLoadingMore) {
                  this.topics = [...this.topics, ...data.conversations];
                } else {
                  this.topics = data.conversations;
                }

                this.totalTopicsCount = data.meta.total;
                this.hasMore = data.meta.has_more;
                this.isFetching = false;
                this.removeScrollListener();
                this.buildSidebarLinks();
                this.attachScrollListener();
              } catch {
                this.isFetching = false;
              }
            }

            loadMore() {
              if (this.isFetching || !this.hasMore) {
                return;
              }

              this.page = this.page + 1;
              this.fetchMessages(true);
            }

            buildSidebarLinks() {
              this.links = this.topics.map(
                (topic) => new AiConversationLink(topic)
              );
            }

            addNewMessage(newTopic) {
              this.links = [new AiConversationLink(newTopic), ...this.links];
            }

            watchForTitleUpdate(topic) {
              const channel = `/discourse-ai/ai-bot/topic/${topic.topic_id}`;
              const topicId = topic.topic_id;
              const callback = this.updateTopicTitle.bind(this);
              messageBus.subscribe(channel, ({ title }) => {
                callback(topicId, title);
                messageBus.unsubscribe(channel);
              });
            }

            updateTopicTitle(topicId, title) {
              // update the topic title in the sidebar, instead of the default title
              const text = document.querySelector(
                `.sidebar-section-link-wrapper .ai-conversation-${topicId} .sidebar-section-link-content-text`
              );
              if (text) {
                text.innerText = title;
              }
            }
          };
        },
        AI_CONVERSATIONS_PANEL
      );

      const setSidebarPanel = (transition) => {
        if (transition?.to?.name === "discourse-ai-bot-conversations") {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        const topic = api.container.lookup("controller:topic").model;
        // if the topic is not a private message, not created by the current user,
        // or doesn't have a bot response, we don't need to override sidebar
        if (
          topic?.archetype === "private_message" &&
          topic.user_id === currentUser.id &&
          topic.postStream.posts.some((post) =>
            isPostFromAiBot(post, currentUser)
          )
        ) {
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        // newTopicForceSidebar is set to true when a new topic is created. We have
        // this because the condition `postStream.posts` above will not be true as the bot response
        // is not in the postStream yet when this initializer is ran. So we need to force
        // the sidebar to open when creating a new topic. After that, we set it to false again.
        if (aiConversationsSidebarManager.newTopicForceSidebar) {
          aiConversationsSidebarManager.newTopicForceSidebar = false;
          return aiConversationsSidebarManager.forceCustomSidebar();
        }

        aiConversationsSidebarManager.stopForcingCustomSidebar();
      };

      api.container
        .lookup("service:router")
        .on("routeDidChange", setSidebarPanel);
    });
  },
};
