import { computed } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { i18n } from "discourse-i18n";
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
    const blankName =
      this.attrs.blankName || i18n("discourse_ai.ai_persona.no_llm_selected");
    return [
      {
        id: "blank",
        name: blankName,
      },
    ].concat(this.llms);
  }
}
