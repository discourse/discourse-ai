import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class ImageCaptionPopup extends Service {
  @tracked showPopup = false;
  @tracked imageIndex = null;
  @tracked imageSrc = null;
  @tracked newCaption = null;
  @tracked loading = false;
  @tracked popupTrigger = null;
  @tracked _request = null;
}
