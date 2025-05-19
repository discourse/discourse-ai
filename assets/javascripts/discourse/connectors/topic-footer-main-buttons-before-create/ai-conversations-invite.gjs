import Component from "@glimmer/component";
import AiConversationsInvite from "../../components/ai-conversations-invite";

export default class AiConversationsInviteConnector extends Component {
  static shouldRender(args) {
    return args.topic.is_bot_pm;
  }

  <template><AiConversationsInvite @topic={{@outletArgs.topic}} /></template>
}
