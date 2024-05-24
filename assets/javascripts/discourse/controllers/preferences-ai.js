import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse-common/config/environment";

const AI_ATTRS = ["auto_image_caption"];

export default class PreferencesAiController extends Controller {
  @service siteSettings;
  @tracked saved = false;

  get canToggleAutoImageCaption() {
    const userGroups = this.model.groups.map((g) => g.id);
    const captionGroups = this.siteSettings.ai_auto_image_caption_allowed_groups
      .split("|")
      .map((id) => parseInt(id, 10));

    return userGroups.some((groupId) => captionGroups.includes(groupId));
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
