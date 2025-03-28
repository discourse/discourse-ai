import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import SmoothStreamer from "../lib/smooth-streamer";
import AiBlinkingAnimation from "./ai-blinking-animation";

const DISCOVERY_TIMEOUT_MS = 10000;

export default class AiSearchDiscoveries extends Component {
  @service search;
  @service messageBus;
  @service discobotDiscoveries;
  @service appEvents;

  @tracked hideDiscoveries = false;
  @tracked fullDiscoveryToggled = false;
  @tracked discoveryPreviewLength = this.args.discoveryPreviewLength || 150;
  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.discobotDiscoveries.discovery,
    (newValue) => (this.discobotDiscoveries.discovery = newValue)
  );

  discoveryTimeout = null;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "full-page-search:trigger-search",
      this,
      this.triggerDiscovery
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "full-page-search:trigger-search",
      this,
      this.triggerDiscovery
    );
  }

  @bind
  detectSearch() {
    if (
      this.query?.length === 0 &&
      this.discobotDiscoveries.discovery?.length > 0
    ) {
      this.discobotDiscoveries.resetDiscovery();
      this.smoothStreamer.resetStreaming();
    }

    withPluginApi((api) => {
      api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
        if (!searchMenu || this.discobotDiscoveries.loadingDiscoveries) {
          return;
        }

        if (this.discobotDiscoveries.lastQuery === this.query) {
          return false;
        }

        if (event.key === "Enter" && this.query) {
          this.triggerDiscovery();
        }
        return true;
      });
    });
  }

  @bind
  async _updateDiscovery(update) {
    if (this.query === update.query) {
      if (this.discoveryTimeout) {
        cancel(this.discoveryTimeout);
      }

      if (!this.discobotDiscoveries.discovery) {
        this.discobotDiscoveries.discovery = "";
      }

      this.discobotDiscoveries.modelUsed = update.model_used;
      this.discobotDiscoveries.loadingDiscoveries = false;
      this.smoothStreamer.updateResult(update, "ai_discover_reply");
    }
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(
      "/discourse-ai/ai-bot/discover",
      this._updateDiscovery
    );
  }

  @bind
  subscribe() {
    this.messageBus.subscribe(
      "/discourse-ai/ai-bot/discover",
      this._updateDiscovery
    );
  }

  get query() {
    return this.args?.searchTerm || this.search.activeGlobalSearchTerm;
  }

  get toggleLabel() {
    if (this.fullDiscoveryToggled) {
      return "discourse_ai.discobot_discoveries.collapse";
    } else {
      return "discourse_ai.discobot_discoveries.tell_me_more";
    }
  }

  get toggleIcon() {
    if (this.fullDiscoveryToggled) {
      return "chevron-up";
    } else {
      return "";
    }
  }

  get canShowExpandtoggle() {
    return (
      !this.discobotDiscoveries.loadingDiscoveries &&
      this.smoothStreamer.renderedText.length > this.discoveryPreviewLength
    );
  }

  get renderPreviewOnly() {
    return !this.fullDiscoveryToggled && this.canShowExpandtoggle;
  }

  @action
  async triggerDiscovery() {
    if (this.discobotDiscoveries.lastQuery === this.query) {
      this.hideDiscoveries = false;
      return;
    } else {
      this.smoothStreamer.resetStreaming();
      this.discobotDiscoveries.resetDiscovery();
    }

    this.hideDiscoveries = false;
    this.discobotDiscoveries.loadingDiscoveries = true;

    this.discoveryTimeout = later(
      this,
      this.timeoutDiscovery,
      DISCOVERY_TIMEOUT_MS
    );

    try {
      this.discobotDiscoveries.lastQuery = this.query;

      await ajax("/discourse-ai/ai-bot/discover", {
        data: { query: this.query },
      });
    } catch {
      this.hideDiscoveries = true;
    }
  }

  @action
  toggleDiscovery() {
    this.fullDiscoveryToggled = !this.fullDiscoveryToggled;
  }

  timeoutDiscovery() {
    this.discobotDiscoveries.loadingDiscoveries = false;
    this.discobotDiscoveries.discovery = "";

    this.discobotDiscoveries.discoveryTimedOut = true;
  }

  <template>
    <div
      class="ai-search-discoveries"
      {{didInsert this.subscribe this.query}}
      {{didUpdate this.subscribe this.query}}
      {{didUpdate this.detectSearch this.query}}
      {{didInsert this.triggerDiscovery this.query}}
      {{willDestroy this.unsubscribe}}
    >
      <div class="ai-search-discoveries__completion">
        {{#if this.discobotDiscoveries.loadingDiscoveries}}
          <AiBlinkingAnimation />
        {{else if this.discobotDiscoveries.discoveryTimedOut}}
          {{i18n "discourse_ai.discobot_discoveries.timed_out"}}
        {{else}}
          <article
            class={{concatClass
              "ai-search-discoveries__discovery"
              (if this.renderPreviewOnly "preview")
              (if this.smoothStreamer.isStreaming "streaming")
              "streamable-content"
            }}
          >
            <div class="cooked">
              <CookText @rawText={{this.smoothStreamer.renderedText}} />
            </div>
          </article>

          {{#if this.canShowExpandtoggle}}
            <DButton
              class="btn-flat btn-text ai-search-discoveries__toggle"
              @label={{this.toggleLabel}}
              @icon={{this.toggleIcon}}
              @action={{this.toggleDiscovery}}
            />
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
