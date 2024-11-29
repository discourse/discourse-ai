import { computed } from "@ember/object";
import { observes } from "@ember-decorators/object";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@selectKitOptions({
  filterable: true,
})
export default class AiLlmSelector extends ComboBox {
  @observes("attrs.disabled")
  _modelDisabledChanged() {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }

  @computed
  get content() {
    return [
      {
        id: "blank",
        name: I18n.t("discourse_ai.ai_persona.no_llm_selected"),
      },
    ].concat(this.llms);
  }
}
