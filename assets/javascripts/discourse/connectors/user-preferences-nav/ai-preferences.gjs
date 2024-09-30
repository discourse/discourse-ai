import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

function showAiPreferences(user, settings) {
  // Since we only have one AI related user setting we don't show
  // AI preferences if these conditions aren't met.
  // If we add more user settings in the future we can move this
  // logic to the the specific settings and conditionally show it in the template.
  const aiHelperEnabledFeatures =
    settings.ai_helper_enabled_features.split("|");

  return (
    user?.user_allowed_ai_auto_image_captions &&
    aiHelperEnabledFeatures.includes("image_caption") &&
    settings.ai_helper_enabled
  );
}

export default class AutoImageCaptionSetting extends Component {
  static shouldRender(outletArgs, helper) {
    return (
      helper.siteSettings.discourse_ai_enabled &&
      showAiPreferences(outletArgs.model, helper.siteSettings)
    );
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
