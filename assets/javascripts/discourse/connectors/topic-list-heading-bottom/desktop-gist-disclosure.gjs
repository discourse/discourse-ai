import Component from "@glimmer/component";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import AiGistDisclosure from "../../components/ai-gist-disclosure";

export default class AiTopicGist extends Component {
  static shouldRender(outletArgs) {
    const router = getOwnerWithFallback(this).lookup("service:router");
    const hasGists = router.currentRoute.attributes.list?.topics?.some(
      (topic) => topic.ai_topic_gist
    );

    return (
      // "default" can be removed after the glimmer topic list is rolled out
      (outletArgs?.name === "default" || outletArgs?.name === "topic.title") &&
      hasGists &&
      !outletArgs.bulkSelectEnabled
    );
  }

  <template>
    <AiGistDisclosure />
  </template>
}
