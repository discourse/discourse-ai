import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { isGPTBot } from "../../lib/ai-bot-helper";

export default class AiPersonaFlair extends Component {
  static shouldRender(args) {
    return isGPTBot(args.post.user);
  }

  @controller("topic") topicController;

  <template>
    <span class="persona-flair">
      {{this.topicController.model.ai_persona_name}}
    </span>
  </template>
}
