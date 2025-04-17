import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import AiBotSidebarNewConversation from "../discourse/components/ai-bot-sidebar-new-conversation";
import { AI_CONVERSATIONS_PANEL } from "../discourse/services/ai-conversations-sidebar-manager";

export default {
  name: "ai-conversations-sidebar",

  initialize() {
    withPluginApi("1.8.0", (api) => {
      const aiConversationsSidebarManager = api.container.lookup(
        "service:ai-conversations-sidebar-manager"
      );
      const currentUser = api.container.lookup("service:current-user");
      const appEvents = api.container.lookup("service:app-events");
      const messageBus = api.container.lookup("service:message-bus");

      if (!currentUser) {
        return;
      }

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
            prefixType = "icon";
            prefixValue = "robot";

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
              // TODO: FIX
              //return i18n(themePrefix("messages_sidebar.title"));
              return "Conversations";
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

            fetchMessages(isLoadingMore = false) {
              if (this.isFetching) {
                return;
              }

              this.isFetching = true;

              ajax("/discourse-ai/ai-bot/conversations.json", {
                data: { page: this.page, per_page: 40 },
              })
                .then((data) => {
                  if (isLoadingMore) {
                    this.topics = [...this.topics, ...data.conversations];
                  } else {
                    this.topics = data.conversations;
                  }

                  this.totalTopicsCount = data.meta.total;
                  this.hasMore = data.meta.more;
                  this.isFetching = false;
                  this.removeScrollListener();
                  this.buildSidebarLinks();
                  this.attachScrollListener();
                })
                .catch(() => {
                  this.isFetching = false;
                });
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
        if (
          topic &&
          topic.archetype === "private_message" &&
          topic.ai_persona_name
        ) {
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
