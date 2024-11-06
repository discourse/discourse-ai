import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";

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
      {{bodyClass "--topic-list-with-gist"}}
      <div class="ai-topic-gist">
        <div class="ai-topic-gist__text">
          {{@topic.ai_topic_gist}}
        </div>
      </div>
    {{/if}}
  </template>
}
