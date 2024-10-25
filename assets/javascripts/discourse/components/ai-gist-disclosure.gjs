import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class AiGistDisclosure extends Component {
  @service router;

  get shouldShow() {
    return this.router.currentRoute.attributes?.list?.topics?.some(
      (topic) => topic.ai_topic_gist
    );
  }

  <template>
    {{#if this.shouldShow}}
      <span class="ai-topic-gist__disclosure">
        {{icon "discourse-sparkles"}}
        {{i18n "discourse_ai.summarization.disclosure"}}
      </span>
    {{/if}}
  </template>
}
