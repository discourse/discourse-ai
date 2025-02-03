import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import htmlClass from "discourse/helpers/html-class";
import getURL from "discourse-common/lib/get-url";

// note the panel for artifact full screen can not be at position 0,0
// otherwise this hack will not activate.
// https://github.com/discourse/discourse/blob/b8325f2190a8c0a9022405c219faeac6f0f98ca5/app/assets/javascripts/discourse/app/components/scrolling-post-stream.js#L77-L77
// this will cause post stream to navigate to a different post

export default class AiArtifactComponent extends Component {
  @service siteSettings;
  @tracked expanded = false;
  @tracked showingArtifact = false;

  constructor() {
    super(...arguments);
    this.keydownHandler = this.handleKeydown.bind(this);
    this.popStateHandler = this.handlePopState.bind(this);
    window.addEventListener("popstate", this.popStateHandler);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("keydown", this.keydownHandler);
    window.removeEventListener("popstate", this.popStateHandler);
  }

  @action
  handleKeydown(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      history.back();
    }
  }

  @action
  handlePopState(event) {
    const state = event.state;
    this.expanded = state?.artifactId === this.args.artifactId;
    if (!this.expanded) {
      window.removeEventListener("keydown", this.keydownHandler);
    }
  }

  get requireClickToRun() {
    if (this.showingArtifact) {
      return false;
    }
    return this.siteSettings.ai_artifact_security === "strict";
  }

  get artifactUrl() {
    let url = getURL(`/discourse-ai/ai-bot/artifacts/${this.args.artifactId}`);

    if (this.args.artifactVersion) {
      url = `${url}/${this.args.artifactVersion}`;
    }
    return url;
  }

  @action
  showArtifact() {
    this.showingArtifact = true;
  }

  @action
  toggleView() {
    if (!this.expanded) {
      window.history.pushState(
        { artifactId: this.args.artifactId },
        "",
        window.location.href + "#artifact-fullscreen"
      );
      window.addEventListener("keydown", this.keydownHandler);
    } else {
      history.back();
    }
    this.expanded = !this.expanded;
  }

  get wrapperClasses() {
    return `ai-artifact__wrapper ${
      this.expanded ? "ai-artifact__expanded" : ""
    }`;
  }

  <template>
    {{#if this.expanded}}
      {{htmlClass "ai-artifact-expanded"}}
    {{/if}}
    <div class={{this.wrapperClasses}}>
      <div class="ai-artifact__panel--wrapper">
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
