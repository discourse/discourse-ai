import { readOnly } from "@ember/object/computed";
import { observes } from "@ember-decorators/object";
import MultiSelectComponent from "select-kit/components/multi-select";
import { selectKitOptions } from "select-kit/components/select-kit";

@selectKitOptions({
  filterable: true,
})
export default class AiToolSelector extends MultiSelectComponent {
  @readOnly("tools") content;

  value = "";

  @observes("attrs.disabled")
  _modelDisabledChanged() {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }
}
