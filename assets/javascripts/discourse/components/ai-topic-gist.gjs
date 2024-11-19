import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { emojiUnescape, sanitize } from "discourse/lib/text";

export default class AiTopicGist extends Component {
  @service gists;

  get shouldShow() {
    return this.gists.preference === "table-ai" && this.gists.shouldShow;
  }

  get gistOrExcerpt() {
    const topic = this.args.topic;
    const gist = topic.get("ai_topic_gist");
    const excerpt = emojiUnescape(sanitize(topic.get("excerpt")));

    return gist || excerpt;
  }

  <template>
    {{#if this.shouldShow}}
      {{#if this.gistOrExcerpt}}
        <div class="excerpt">
          <div>{{htmlSafe this.gistOrExcerpt}}</div>
        </div>
      {{/if}}
    {{/if}}
  </template>
}
