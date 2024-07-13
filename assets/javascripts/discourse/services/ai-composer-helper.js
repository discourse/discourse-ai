import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class AiComposerHelper extends Service {
  @tracked menuState = this.MENU_STATES.triggers;

  MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    resets: "RESETS",
    loading: "LOADING",
    review: "REVIEW",
  };
}
