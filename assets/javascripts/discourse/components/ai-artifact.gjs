import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import htmlClass from "discourse/helpers/html-class";
import getURL from "discourse-common/lib/get-url";

export default class AiArtifactComponent extends Component {
  @tracked expanded = false;

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

  get artifactUrl() {
    return getURL(`/discourse-ai/ai-bot/artifacts/${this.args.artifactId}`);
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
      <iframe
        title="AI Artifact"
        src={{this.artifactUrl}}
        width="100%"
        frameborder="0"
        sandbox="allow-scripts allow-forms"
      ></iframe>
      <div class="ai-artifact__footer">
        <DButton
          class="btn-flat btn-icon-text ai-artifact__expand-button"
          @icon="discourse-expand"
          @label="discourse_ai.ai_artifact.expand_view_label"
          @action={{this.toggleView}}
        />
      </div>
    </div>
  </template>
}
