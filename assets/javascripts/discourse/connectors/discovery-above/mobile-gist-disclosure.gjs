import Component from "@glimmer/component";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import AiGistDisclosure from "../../components/ai-gist-disclosure";

export default class AiTopicGistDisclosure extends Component {
  static shouldRender(outletArgs, helper) {
    const isMobileView = helper.site.mobileView;
    const router = getOwnerWithFallback(this).lookup("service:router");
    const hasGists = router.currentRoute.attributes.list?.topics?.some(
      (topic) => topic.ai_topic_gist
    );

    return hasGists && isMobileView;
  }

  <template>
    <AiGistDisclosure />
  </template>
}
