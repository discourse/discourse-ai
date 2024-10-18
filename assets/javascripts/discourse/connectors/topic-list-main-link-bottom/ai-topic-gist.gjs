import Component from "@glimmer/component";

export default class AiTopicGist extends Component {
  static shouldRender(outletArgs) {
    return outletArgs?.topic?.ai_topic_gist && !outletArgs.topic.excerpt;
  }

  <template>
    <div class="ai-topic-gist">
      <div class="ai-topic-gist__text">
        {{@outletArgs.topic.ai_topic_gist}}
      </div>
    </div>
  </template>
}
