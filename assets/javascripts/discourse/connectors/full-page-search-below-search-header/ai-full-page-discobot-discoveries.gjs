import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(_args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_bot_discover_persona &&
      currentUser?.can_use_ai_bot_discover_persona
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
        <span>
          {{icon "discobot"}}
          {{i18n "discourse_ai.discobot_discoveries.main_title"}}
        </span>

        <span class="ai-search-discoveries-tooltip">
          <DTooltip @placement="top-end">
            <:trigger>
              {{icon "circle-info"}}
            </:trigger>
            <:content>
              <div class="ai-search-discoveries-tooltip__content">
                <div class="ai-search-discoveries-tooltip__header">
                  {{i18n "discourse_ai.discobot_discoveries.tooltip.header"}}
                </div>

                <div class="ai-search-discoveries-tooltip__content">
                  {{#if this.discobotDiscoveries.modelUsed}}
                    {{i18n
                      "discourse_ai.discobot_discoveries.tooltip.content"
                      model=this.discobotDiscoveries.modelUsed
                    }}
                  {{/if}}
                </div>
              </div>
            </:content>
          </DTooltip>
        </span>
      </h3>
      <div class="full-page-discoveries">
        <AiSearchDiscoveries @searchTerm={{@outletArgs.search}} />
      </div>
    {{/if}}
  </template>
}
