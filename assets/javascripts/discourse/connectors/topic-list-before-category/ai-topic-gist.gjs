import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class AiTopicGist extends Component {
  static shouldRender(outletArgs) {
    return outletArgs?.topic?.ai_topic_gist && !outletArgs.topic.excerpt;
  }

  @service gistPreference;

  get showGists() {
    return this.gistPreference.preference === "gists_enabled";
  }

  <template>
    {{#if this.showGists}}
      <div class="ai-topic-gist">
        <div class="ai-topic-gist__text">
          {{@outletArgs.topic.ai_topic_gist}}
        </div>
      </div>
    {{/if}}
  </template>
}
