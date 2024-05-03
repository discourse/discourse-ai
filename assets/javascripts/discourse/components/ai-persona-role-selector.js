import { computed, observer } from "@ember/object";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default ComboBox.extend({
  _modelDisabledChanged: observer("attrs.disabled", function () {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }),

  content: computed(function () {
    return [
      {
        id: "bot",
        name: I18n.t("discourse_ai.ai_persona.role_options.bot"),
      },
      {
        id: "message_responder",
        name: I18n.t("discourse_ai.ai_persona.role_options.message_responder"),
      },
    ];
  }),

  selectKitOptions: {
    filterable: false,
  },
});
