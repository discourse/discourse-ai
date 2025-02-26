import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AiBlinkingAnimation from "./ai-blinking-animation";

const DISCOVERY_TIMEOUT_MS = 10000;
const BUFFER_WORDS_COUNT = 50;

function setUpBuffer(discovery, bufferTarget) {
  const paragraphs = discovery.split(/\n+/);
  let wordCount = 0;
  const paragraphBuffer = [];

  for (const paragraph of paragraphs) {
    const wordsInParagraph = paragraph.split(/\s+/);
    wordCount += wordsInParagraph.length;

    if (wordCount >= bufferTarget) {
      paragraphBuffer.push(paragraph.concat("..."));
      return paragraphBuffer.join("\n");
    } else {
      paragraphBuffer.push(paragraph);
      paragraphBuffer.push("\n");
    }
  }

  return null;
}

export default class AiSearchDiscoveries extends Component {
  @service search;
  @service messageBus;
  @service discobotDiscoveries;

  @tracked loadingDiscoveries = false;
  @tracked hideDiscoveries = false;
  @tracked fullDiscoveryToggled = false;

  discoveryTimeout = null;

  @bind
  async _updateDiscovery(update) {
    if (this.query === update.query) {
      if (this.discoveryTimeout) {
        cancel(this.discoveryTimeout);
      }

      this.discobotDiscoveries.modelUsed = update.model_used;
      this.discobotDiscoveries.discovery = update.ai_discover_reply;

      // Handling short replies.
      if (update.done) {
        this.discobotDiscoveries.discovery = update.ai_discover_reply;
        this.loadingDiscoveries = false;
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
    // TODO: add check for height/char length if text is long enough...
    return !this.loadingDiscoveries;
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
      {{didInsert this.subscribe}}
      {{didInsert this.triggerDiscovery this.query}}
      {{willDestroy this.unsubscribe}}
    >
      <div class="ai-search-discoveries__completion">
        {{#if this.loadingDiscoveries}}
          <AiBlinkingAnimation />
        {{else if this.discobotDiscoveries.discoveryTimedOut}}
          {{i18n "discourse_ai.discobot_discoveries.timed_out"}}
        {{else}}
          <div
            class="ai-search-discoveries__discovery cooked
              {{concatClass (if (not this.fullDiscoveryToggled) 'preview')}}"
          >
            <CookText @rawText={{this.discobotDiscoveries.discovery}} />
          </div>

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
