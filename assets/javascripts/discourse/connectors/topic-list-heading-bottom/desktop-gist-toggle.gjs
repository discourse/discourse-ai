import Component from "@glimmer/component";
import AiGistToggle from "../../components/ai-gist-toggle";

export default class AiTopicGist extends Component {
  static shouldRender(outletArgs) {
    return (
      // "default" can be removed after the glimmer topic list is rolled out
      (outletArgs?.name === "default" || outletArgs?.name === "topic.title") &&
      !outletArgs.bulkSelectEnabled
    );
  }

  <template>
    <AiGistToggle />
  </template>
}
