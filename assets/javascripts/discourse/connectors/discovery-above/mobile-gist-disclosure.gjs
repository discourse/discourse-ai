import Component from "@glimmer/component";
import AiGistDisclosure from "../../components/ai-gist-disclosure";

export default class AiTopicGistDisclosure extends Component {
  static shouldRender(outletArgs, helper) {
    const isMobileView = helper.site.mobileView;
    return isMobileView;
  }

  <template>
    <AiGistDisclosure />
  </template>
}
