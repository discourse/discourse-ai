import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class AiTopicGist extends Component {
  @service router;
  @service gistPreference;

  get prefersGist() {
    return this.gistPreference.preference === "gists_enabled";
  }

  get showGist() {
    return (
      this.router.currentRoute.attributes?.filterType === "hot" &&
      this.args.topic?.ai_topic_gist &&
      !this.args.topic?.excerpt &&
      this.prefersGist &&
      !this.args.topic?.excerpt
    );
  }

  <template>
    {{#if this.showGist}}
      <div class="ai-topic-gist">
        <div class="ai-topic-gist__text">
          {{@topic.ai_topic_gist}}
        </div>
      </div>
    {{/if}}
  </template>
}
