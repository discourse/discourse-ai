import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";

const AI_ATTRS = ["auto_image_caption"];

export default class PreferencesAiController extends Controller {
  @service siteSettings;
  @tracked saved = false;

  get showAutoImageCaptionSetting() {
    const aiHelperEnabledFeatures =
      this.siteSettings.ai_helper_enabled_features.split("|");

    return (
      this.model?.user_allowed_ai_auto_image_captions &&
      aiHelperEnabledFeatures.includes("image_caption") &&
      this.siteSettings.ai_helper_enabled
    );
  }

  @action
  save() {
    this.saved = false;

    return this.model
      .save(AI_ATTRS)
      .then(() => {
        this.saved = true;
        if (!isTesting()) {
          location.reload();
        }
      })
      .catch(popupAjaxError);
  }
}
