import { computed } from "@ember/object";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default ComboBox.extend({
  content: computed(function () {
    const content = [
      {
        id: -1,
        name: I18n.t("discourse_ai.ai_persona.tool_strategies.all"),
      },
    ];

    [1, 2, 5].forEach((i) => {
      content.push({
        id: i,
        name: I18n.t("discourse_ai.ai_persona.tool_strategies.replies", {
          count: i,
        }),
      });
    });

    return content;
  }),

  selectKitOptions: {
    filterable: false,
  },
});
