import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import htmlClass from "discourse/helpers/html-class";
import getURL from "discourse-common/lib/get-url";

export default class AiArtifactComponent extends Component {
  @service siteSettings;
  @tracked expanded = false;
  @tracked showingArtifact = false;

  constructor() {
    super(...arguments);
    this.keydownHandler = this.handleKeydown.bind(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("keydown", this.keydownHandler);
  }

  @action
  handleKeydown(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      this.expanded = false;
    }
  }

  get requireClickToRun() {
    if (this.showingArtifact) {
      return false;
    }
    return this.siteSettings.ai_artifact_security === "strict";
  }

  get artifactUrl() {
    const url = getURL(
      `/discourse-ai/ai-bot/artifacts/${this.args.artifactId}`
    );

    if (this.args.artifactVersion) {
      return `${url}?version=${this.args.artifactVersion}`;
    } else {
      return url;
    }
  }

  @action
  showArtifact() {
    this.showingArtifact = true;
  }

  @action
  toggleView() {
    this.expanded = !this.expanded;
    if (this.expanded) {
      window.addEventListener("keydown", this.keydownHandler);
    } else {
      window.removeEventListener("keydown", this.keydownHandler);
    }
  }

  get wrapperClasses() {
    return `ai-artifact__wrapper ${
      this.expanded ? "ai-artifact__expanded" : ""
    }`;
  }

  @action
  artifactPanelHover() {
    // retrrigger animation
    const panel = document.querySelector(".ai-artifact__panel");
    panel.style.animation = "none"; // Stop the animation
    setTimeout(() => {
      panel.style.animation = ""; // Re-trigger the animation by removing the none style
    }, 0);
  }

  <template>
    {{#if this.expanded}}
      {{htmlClass "ai-artifact-expanded"}}
    {{/if}}
    <div class={{this.wrapperClasses}}>
      <div
        class="ai-artifact__panel--wrapper"
        {{on "mouseleave" this.artifactPanelHover}}
      >
        <div class="ai-artifact__panel">
          <DButton
            class="btn-flat btn-icon-text"
            @icon="discourse-compress"
            @label="discourse_ai.ai_artifact.collapse_view_label"
            @action={{this.toggleView}}
          />
        </div>
      </div>
      {{#if this.requireClickToRun}}
        <div class="ai-artifact__click-to-run">
          <DButton
            class="btn btn-primary"
            @icon="play"
            @label="discourse_ai.ai_artifact.click_to_run_label"
            @action={{this.showArtifact}}
          />
        </div>
      {{else}}
        <iframe
          title="AI Artifact"
          src={{this.artifactUrl}}
          width="100%"
          frameborder="0"
        ></iframe>
      {{/if}}
      {{#unless this.requireClickToRun}}
        <div class="ai-artifact__footer">
          <DButton
            class="btn-flat btn-icon-text ai-artifact__expand-button"
            @icon="discourse-expand"
            @label="discourse_ai.ai_artifact.expand_view_label"
            @action={{this.toggleView}}
          />
        </div>
      {{/unless}}
    </div>
  </template>
}
