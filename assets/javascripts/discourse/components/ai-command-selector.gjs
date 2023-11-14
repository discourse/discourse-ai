import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  choices: [{name: "search", value: "search"} ],
  nameProperty: "name",
  valueProperty: "value",

  selectKitOptions: {
    filterable: true,
  },
  search(term) {
    let commands = this.siteSettings.ai_bot_enabled_chat_commands.split("|");

    commands = commands.filter(function(command) {
      return command.includes(term);
    });

    commands = commands.map(function(command) {
      return {name: command, value: command};
    });

    return Promise.resolve(commands);
  }
});


