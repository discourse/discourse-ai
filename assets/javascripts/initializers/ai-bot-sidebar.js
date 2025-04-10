import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import AiBotSidebarNewConversation from "../discourse/components/ai-bot-sidebar-new-conversation";

export default {
  name: "custom-sidebar-bot-messages",
  initialize() {
    withPluginApi("1.37.1", (api) => {
      const currentUser = api.container.lookup("service:current-user");
      const appEvents = api.container.lookup("service:app-events");
      const messageBus = api.container.lookup("service:message-bus");

      if (!currentUser) {
        return;
      }

      // TODO: Replace
      const recentConversations = 10;

      api.renderInOutlet("after-sidebar-sections", AiBotSidebarNewConversation);

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            @tracked links = [];
            @tracked topics = [];
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

            fetchMessages() {
              if (this.isFetching) {
                return;
              }

              this.isFetching = true;

              ajax("/discourse-ai/ai-bot/conversations.json")
                .then((data) => {
                  this.topics = data.conversations.slice(
                    0,
                    recentConversations
                  );
                  this.isFetching = false;
                  this.buildSidebarLinks();
                })
                .catch((e) => {
                  debugger;
                  this.isFetching = false;
                });
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
                })();

              this.links = [builtTopic, ...this.links];
            }

            buildSidebarLinks() {
              this.links = this.topics.map((topic) => {
                return new (class extends BaseCustomSidebarSectionLink {
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
                })();
              });

              if (this.totalTopicsCount > recentConversations) {
                this.links.push(
                  new (class extends BaseCustomSidebarSectionLink {
                    name = "View All";
                    route = "userPrivateMessages.user.index";
                    models = [currentUser.username];
                    title = "View all...";
                    text = "View all...";
                    prefixType = "icon";
                    prefixValue = "list";
                  })()
                );
              }
            }

            watchForTitleUpdate(topic) {
              const channel = `/discourse-ai/ai-bot/topic/${topic.topic_id}`;
              messageBus.subscribe(channel, () => {
                this.fetchMessages();
                messageBus.unsubscribe(channel);
              });
            }

            get name() {
              return "custom-messages";
            }

            get text() {
              // TODO: FIX
              //return i18n(themePrefix("messages_sidebar.title"));
              return "Conversations";
            }

            get displaySection() {
              return this.links?.length > 0;
            }
          };
        }
      );
    });
  },
};
