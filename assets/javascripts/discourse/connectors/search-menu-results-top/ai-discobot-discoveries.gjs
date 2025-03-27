import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import AiSearchDiscoveriesTooltip from "../../components/ai-search-discoveries-tooltip";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_bot_discover_persona &&
      currentUser?.can_use_ai_bot_discover_persona &&
      currentUser?.user_option?.ai_search_discoveries
    );
  }

  @service discobotDiscoveries;

  <template>
    <div class="ai-discobot-discoveries">
      <h3 class="ai-search-discoveries__discoveries-title">
        <span>
          {{icon "discobot"}}
          {{i18n "discourse_ai.discobot_discoveries.main_title"}}
        </span>

        <AiSearchDiscoveriesTooltip />
      </h3>

      <AiSearchDiscoveries
        @searchTerm={{@outletArgs.searchTerm}}
        @discoveryPreviewLength={{50}}
      />

      <h3 class="ai-search-discoveries__regular-results-title">
        {{icon "bars-staggered"}}
        {{i18n "discourse_ai.discobot_discoveries.regular_results"}}
      </h3>
    </div>
  </template>
}
