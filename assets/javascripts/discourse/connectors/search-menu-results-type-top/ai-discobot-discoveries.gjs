import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      args.resultType.type === "topic" &&
      siteSettings.ai_bot_discover_persona &&
      currentUser.can_use_ai_bot_discover_persona
    );
  }

  @service discobotDiscoveries;

  <template>
    <div class="ai-discobot-discoveries">
      <h3 class="ai-search-discoveries__discoveries-title">
        {{icon "robot"}}
        {{i18n "discourse_ai.discobot_discoveries.main_title"}}
      </h3>

      <AiSearchDiscoveries />

      <h3 class="ai-discobot-discoveries__regular-results-title">
        {{icon "bars-staggered"}}
        {{i18n "discourse_ai.discobot_discoveries.regular_results"}}
      </h3>
    </div>
  </template>
}
