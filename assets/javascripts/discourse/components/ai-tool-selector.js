import { observer } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  _modelDisabledChanged: observer("attrs.disabled", function () {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }),

  content: readOnly("tools"),

  value: "",

  selectKitOptions: {
    filterable: true,
  },
});
