import Component from "@glimmer/component";
import AiGistToggle from "../../components/ai-gist-toggle";

export default class AiTopicGistToggle extends Component {
  static shouldRender(outletArgs, helper) {
    const isMobileView = helper.site.mobileView;
    return isMobileView;
  }

  <template>
    <AiGistToggle />
  </template>
}
