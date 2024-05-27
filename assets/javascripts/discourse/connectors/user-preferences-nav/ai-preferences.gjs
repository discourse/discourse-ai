import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class AutoImageCaptionSetting extends Component {
  static shouldRender(outletArgs, helper) {
    return helper.siteSettings.discourse_ai_enabled;
  }

  <template>
    <li class="user-nav__preferences-ai">
      <LinkTo @route="preferences.ai">
        {{dIcon "discourse-sparkles"}}
        <span>{{i18n "discourse_ai.title"}}</span>
      </LinkTo>
    </li>
  </template>
}
