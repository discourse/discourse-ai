import Component from "@glimmer/component";
import AiGistDisclosure from "../../components/ai-gist-disclosure";

export default class AiTopicGistDisclosure extends Component {
  static shouldRender(outletArgs, helper) {
    const isMobileView = helper.site.mobileView;
    const containsAiTopicGist = helper.session?.topicList?.topics?.some(
      (topic) => topic.ai_topic_gist
    );

    return containsAiTopicGist && isMobileView;
  }

  <template>
    <AiGistDisclosure />
  </template>
}
