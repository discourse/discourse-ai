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
import { i18n } from "discourse-i18n";
import AiBlinkingAnimation from "./ai-blinking-animation";

const DISCOVERY_TIMEOUT_MS = 10000;
const STREAMED_TEXT_SPEED = 23;

export default class AiSearchDiscoveries extends Component {
  @service search;
  @service messageBus;
  @service discobotDiscoveries;

  @tracked loadingDiscoveries = false;
  @tracked hideDiscoveries = false;
  @tracked fullDiscoveryToggled = false;
  @tracked discoveryPreviewLength = this.args.discoveryPreviewLength || 150;

  @tracked isStreaming = false;
  @tracked streamedText = "";

  discoveryTimeout = null;
  typingTimer = null;
  streamedTextLength = 0;

  typeCharacter() {
    if (this.streamedTextLength < this.discobotDiscoveries.discovery.length) {
      this.streamedText += this.discobotDiscoveries.discovery.charAt(
        this.streamedTextLength
      );
      this.streamedTextLength++;

      this.typingTimer = later(this, this.typeCharacter, STREAMED_TEXT_SPEED);
    } else {
      this.typingTimer = null;
    }
  }

  onTextUpdate() {
    if (this.typingTimer) {
      cancel(this.typingTimer);
    }

    this.typeCharacter();
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

      const newText = update.ai_discover_reply;
      this.discobotDiscoveries.modelUsed = update.model_used;
      this.loadingDiscoveries = false;

      // Handling short replies.
      if (update.done) {
        this.discobotDiscoveries.discovery = newText;
        this.streamedText = newText;
        this.isStreaming = false;

        // Clear pending animations
        if (this.typingTimer) {
          cancel(this.typingTimer);
          this.typingTimer = null;
        }
      } else if (newText.length > this.discobotDiscoveries.discovery.length) {
        this.discobotDiscoveries.discovery = newText;
        this.isStreaming = true;
        await this.onTextUpdate();
      }
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
      !this.loadingDiscoveries &&
      this.renderedDiscovery.length > this.discoveryPreviewLength
    );
  }

  get renderedDiscovery() {
    return this.isStreaming
      ? this.streamedText
      : this.discobotDiscoveries.discovery;
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
      this.discobotDiscoveries.resetDiscovery();
    }

    this.hideDiscoveries = false;
    this.loadingDiscoveries = true;
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
    this.loadingDiscoveries = false;
    this.discobotDiscoveries.discovery = "";

    this.discobotDiscoveries.discoveryTimedOut = true;
  }

  <template>
    <div
      class="ai-search-discoveries"
      {{didInsert this.subscribe @searchTerm}}
      {{didUpdate this.subscribe @searchTerm}}
      {{didInsert this.triggerDiscovery this.query}}
      {{willDestroy this.unsubscribe}}
    >
      <div class="ai-search-discoveries__completion">
        {{#if this.loadingDiscoveries}}
          <AiBlinkingAnimation />
        {{else if this.discobotDiscoveries.discoveryTimedOut}}
          {{i18n "discourse_ai.discobot_discoveries.timed_out"}}
        {{else}}
          <article
            class={{concatClass
              "ai-search-discoveries__discovery"
              (if this.renderPreviewOnly "preview")
              (if this.isStreaming "streaming")
              "streamable-content"
            }}
          >
            <div class="cooked">
              <CookText @rawText={{this.renderedDiscovery}} />
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
