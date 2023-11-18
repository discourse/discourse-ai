import { computed, observer } from "@ember/object";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  _modelDisabledChanged: observer("attrs.disabled", function () {
    this.selectKit.options.set("disabled", this.get("attrs.disabled.value"));
  }),

  content: computed(function () {
    // TODO: maybe we should sideload this in via serializer
    return [
      { id: "SearchCommand", name: "Search" },
      { id: "SummarizeCommand", name: "Summarize" },
      { id: "ReadCommand", name: "Read" },
      { id: "TagsCommand", name: "Tags" },
      { id: "ImageCommand", name: "Image" },
      { id: "GoogleCommand", name: "Google" },
      { id: "CategoriesCommand", name: "Categories" },
      { id: "TimeCommand", name: "Time" },
      { id: "DbSchemaCommand", name: "DB Schema" },
      { id: "SearchSettingsCommand", name: "Search Settings" },
      { id: "SettingContextCommand", name: "Setting Context" },
    ];
  }),

  value: "",

  selectKitOptions: {
    filterable: true,
  },
});
