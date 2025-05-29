import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";
import AiBotSidebarEmptyState from "../../discourse/components/ai-bot-sidebar-empty-state";

export const AI_CONVERSATIONS_PANEL = "ai-conversations";

export default class AiConversationsSidebarManager extends Service {
  @service appEvents;
  @service sidebarState;

  @tracked newTopicForceSidebar = false;
  @tracked sections = new TrackedArray();
  @tracked isLoading = true;

  isFetching = false;
  page = 0;
  hasMore = true;

  loadedTodayLabel = false;
  loadedSevenDayLabel = false;
  loadedThirtyDayLabel = false;
  loadedMonthLabels = new Set();

  forceCustomSidebar(api) {
    // Return early if we already have the correct panel, so we don't
    // re-render it.

    if (this.sidebarState.currentPanel?.key === AI_CONVERSATIONS_PANEL) {
      return;
    }

    schedule("afterRender", async () => {
      await this.fetchMessages(api);
      this.sidebarState.setPanel("ai-conversations");
    });

    this.sidebarState.setPanel(AI_CONVERSATIONS_PANEL);

    // Use separated mode to ensure independence from hamburger menu
    this.sidebarState.setSeparatedMode();

    // Hide panel switching buttons to keep UI clean
    this.sidebarState.hideSwitchPanelButtons();

    this.sidebarState.isForcingSidebar = true;
    document.body.classList.add("has-ai-conversations-sidebar");
    this.appEvents.trigger("discourse-ai:force-conversations-sidebar");
    return true;
  }

  stopForcingCustomSidebar() {
    // This method is called when leaving your route
    // Only restore main panel if we previously forced ours
    document.body.classList.remove("has-ai-conversations-sidebar");
    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;
    // only restore main panel if we previously forced our sidebar
    // and not if we are in admin sidebar
    if (this.sidebarState.isForcingSidebar && !isAdminSidebarActive) {
      this.sidebarState.setPanel(MAIN_PANEL); // Return to main sidebar panel
      this.sidebarState.isForcingSidebar = false;
      this.appEvents.trigger("discourse-ai:stop-forcing-conversations-sidebar");
    }
  }

  async fetchMessages(api) {
    if (this.isFetching) {
      return;
    }
    this.isFetching = true;

    try {
      let { conversations, meta } = await ajax(
        "/discourse-ai/ai-bot/conversations.json",
        { data: { page: this.page, per_page: 40 } }
      );

      this.page += 1;
      this.hasMore = meta.has_more;

      // Append new topics and rebuild groups
      this._topics = [...(this._topics || []), ...conversations];
    } catch {
      this.isFetching = false;
      this.isLoading = false;
    } finally {
      this.isFetching = false;
      this.isLoading = false;
      this.buildSections(api);
    }
  }

  buildSections(api) {
    // reset grouping flags
    this.loadedTodayLabel = false;
    this.loadedSevenDayLabel = false;
    this.loadedThirtyDayLabel = false;
    this.loadedMonthLabels.clear();

    const now = new Date();
    const sections = [];
    let currentSection = null;

    (this._topics || []).forEach((topic) => {
      const heading = this.groupByDate(topic, now);

      // new section for new heading
      if (heading) {
        currentSection = {
          title: heading.text,
          name: heading.name,
          classNames: heading.classNames,
          links: new TrackedArray(),
        };
        sections.push(currentSection);
      }

      // always add topic link under the latest section
      if (currentSection) {
        currentSection.links.push({
          route: "topic.fromParamsNear",
          models: [topic.slug, topic.id, topic.last_read_post_number || 0],
          title: topic.title,
          text: topic.title,
          key: topic.id,
          classNames: `ai-conversation-${topic.id}`,
        });
      }
    });

    this.sections = sections;

    this.mountSections(api);
  }

  mountSections(api) {
    this.sections.forEach((section) => {
      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          return class extends BaseCustomSidebarSection {
            get name() {
              return section.name;
            }

            get title() {
              return section.title;
            }

            get text() {
              return section.title;
            }

            get links() {
              return section.links.map(
                (link) =>
                  new (class extends BaseCustomSidebarSectionLink {
                    get name() {
                      return `conv-${link.key}`;
                    }

                    get route() {
                      return link.route;
                    }

                    get models() {
                      return link.models;
                    }

                    get title() {
                      return link.title;
                    }

                    get text() {
                      return link.text;
                    }
                  })()
              );
            }

            get emptyStateComponent() {
              if (!this.isLoading && section.links.length === 0) {
                return AiBotSidebarEmptyState;
              }
            }

            get sidebarElement() {
              return document.querySelector(
                ".sidebar-wrapper .sidebar-sections"
              );
            }
          };
        },
        AI_CONVERSATIONS_PANEL
      );
    });

    this.appEvents.trigger("discourse-ai:conversations-sidebar-updated");
  }

  groupByDate(topic, now = new Date()) {
    const lastPostedAt = new Date(topic.last_posted_at);
    const daysDiff = Math.round((now - lastPostedAt) / (1000 * 60 * 60 * 24));

    // Today
    if (daysDiff <= 1 || !topic.last_posted_at) {
      if (!this.loadedTodayLabel) {
        this.loadedTodayLabel = true;
        return {
          text: i18n("discourse_ai.ai_bot.conversations.today"),
          classNames: "date-heading",
          name: "date-heading-today",
        };
      }
    }
    // Last 7 days
    else if (daysDiff <= 7) {
      if (!this.loadedSevenDayLabel) {
        this.loadedSevenDayLabel = true;
        return {
          text: i18n("discourse_ai.ai_bot.conversations.last_7_days"),
          classNames: "date-heading",
          name: "date-heading-last-7-days",
        };
      }
    }
    // Last 30 days
    else if (daysDiff <= 30) {
      if (!this.loadedThirtyDayLabel) {
        this.loadedThirtyDayLabel = true;
        return {
          text: i18n("discourse_ai.ai_bot.conversations.last_30_days"),
          classNames: "date-heading",
          name: "date-heading-last-30-days",
        };
      }
    }
    // Older: group by month
    else {
      const month = lastPostedAt.getMonth();
      const year = lastPostedAt.getFullYear();
      const monthKey = `${year}-${month}`;

      if (!this.loadedMonthLabels.has(monthKey)) {
        this.loadedMonthLabels.add(monthKey);
        const formattedDate = autoUpdatingRelativeAge(lastPostedAt);
        return {
          text: htmlSafe(formattedDate),
          classNames: "date-heading",
          name: `date-heading-${monthKey}`,
        };
      }
    }

    return null;
  }
}
