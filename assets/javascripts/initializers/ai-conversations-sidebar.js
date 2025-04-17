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

              appEvents.on("topic:created", (topic) => {
                // when asking a new question
                this.addNewMessage(topic);
                this.watchForTitleUpdate(topic);
              });
            }

            willDestroy() {
              this.removeScrollListener();
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

            get sidebarElement() {
              return document.querySelector(
                ".sidebar-wrapper .sidebar-sections"
              );
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
                    // Append to existing topics
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

            addNewMessage(newTopic) {
              // the pm endpoint isn't fast enough include the newly created topic
              // so this adds the new topic to the existing list
              const builtTopic =
                new (class extends BaseCustomSidebarSectionLink {
                  name = newTopic.title;
                  route = "topic.fromParamsNear";
                  models = [newTopic.topic_slug, newTopic.topic_id, 0];
                  title = newTopic.title;
                  text = newTopic.title;
                  prefixType = "icon";
                  prefixValue = "robot";
                  classNames = `ai-conversation-${newTopic.topic_id}`;
                })();

              this.links = [builtTopic, ...this.links];
            }

            createBotConversationLink(SuperClass, topic) {
              return new (class extends SuperClass {
                name = topic.title;
                route = "topic.fromParamsNear";
                models = [
                  topic.slug,
                  topic.id,
                  topic.last_read_post_number || 0,
                ];
                title = topic.title;
                text = topic.title;
                prefixType = "icon";
                prefixValue = "robot";
                classNames = `ai-conversation-${topic.id}`;
              })();
            }

            buildSidebarLinks() {
              this.links = this.topics.map((topic) =>
                this.createBotConversationLink(
                  BaseCustomSidebarSectionLink,
                  topic
                )
              );
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

            get name() {
              return "ai-conversations-history";
            }

            get text() {
              // TODO: FIX
              //return i18n(themePrefix("messages_sidebar.title"));
              return "Conversations";
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
