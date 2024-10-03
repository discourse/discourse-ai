import { computed, observer } from "@ember/object";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  _modelDisabledChanged: observer("attrs.disabled", function () {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }),

  content: computed("tools", function () {
    return this.tools;
  }),

  value: "",

  selectKitOptions: {
    filterable: true,
  },
});
