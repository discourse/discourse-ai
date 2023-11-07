import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import I18n from "discourse-i18n";

const i18n = I18n.t.bind(I18n);

export default class AISentimentDashboard extends Component {
  <template>
    <li class="navigation-item sentiment">
      <LinkTo @route="admin.dashboardSentiment" class="navigation-link">
        {{i18n "discourse_ai.sentiments.dashboard.title"}}
      </LinkTo>
    </li>
  </template>

  static shouldRender(_outletArgs, helper) {
    return helper.siteSettings.ai_sentiment_enabled;
  }
}
