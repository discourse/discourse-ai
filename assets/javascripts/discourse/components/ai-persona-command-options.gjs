import Component from "@glimmer/component";
import I18n from "discourse-i18n";
import AiPersonaCommandOptionEditor from "./ai-persona-command-option-editor";

export default class AiPersonaCommandOptions extends Component {
  get showCommandOptions() {
    const allCommands = this.args.allCommands;
    if (!allCommands) {
      return false;
    }

    return this.commandNames.any(
      (command) => allCommands.find((c) => c.id === command)?.options
    );
  }

  get commandNames() {
    if (!this.args.commands) {
      return [];
    }
    return this.args.commands.map((command) => {
      if (typeof command === "string") {
        return command;
      } else {
        return command[0];
      }
    });
  }

  get commandOptions() {
    if (!this.args.commands) {
      return [];
    }

    const allCommands = this.args.allCommands;
    if (!allCommands) {
      return [];
    }

    const options = [];
    this.commandNames.forEach((commandId) => {
      const command = allCommands.find((c) => c.id === commandId);

      const commandName = command?.name;
      const commandOptions = command?.options;

      if (commandOptions) {
        const mappedOptions = Object.keys(commandOptions).map((key) => {
          const value = this.args.persona.getCommandOption(commandId, key);
          return Object.assign({}, commandOptions[key], { id: key, value });
        });

        options.push({ commandName, options: mappedOptions });
      }
    });

    return options;
  }

  <template>
    {{#if this.showCommandOptions}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.command_options"}}</label>
        <div>
          {{#each this.commandOptions as |commandOption|}}
            <div class="ai-persona-editor__command-options">
              <div class="ai-persona-editor__command-options-name">
                {{commandOption.commandName}}
              </div>
              <div class="ai-persona-editor__command-option-options">
                {{#each commandOption.options as |option|}}
                  <AiPersonaCommandOptionEditor @option={{option}} />
                {{/each}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
