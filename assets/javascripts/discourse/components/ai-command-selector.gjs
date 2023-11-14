import { computed } from "@ember/object";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({

  content: computed(function() {
    const commands = this.siteSettings.ai_bot_enabled_chat_commands.split("|");
    return commands.map(function(command) {
      return {id: command, name: command};
    });
  }),

  value: "",

  selectKitOptions: {
    filterable: true,
  },
});


