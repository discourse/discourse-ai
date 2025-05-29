import Component from "@glimmer/component";
import { isGPTBot } from "../../lib/ai-bot-helper";

export default class AiAgentFlair extends Component {
  static shouldRender(args) {
    return isGPTBot(args.post.user);
  }

  <template>
    <span class="agent-flair">
      {{@outletArgs.post.topic.ai_agent_name}}
    </span>
  </template>
}
