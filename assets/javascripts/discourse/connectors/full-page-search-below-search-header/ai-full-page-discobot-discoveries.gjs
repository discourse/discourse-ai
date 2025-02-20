import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(_args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_bot_discover_persona &&
      currentUser.can_use_ai_bot_discover_persona
    );
  }

  @service discobotDiscoveries;

  get hasDiscoveries() {
    return this.args.outletArgs?.model?.topics?.length > 0;
  }

  <template>
    {{#if this.hasDiscoveries}}
      <h3
        class="ai-search-discoveries__discoveries-title full-page-discoveries"
      >
        {{icon "robot"}}
        {{i18n "discourse_ai.discobot_discoveries.main_title"}}
      </h3>
      <div class="full-page-discoveries">
        <AiSearchDiscoveries @searchTerm={{@outletArgs.search}} />
      </div>
    {{/if}}
  </template>
}
