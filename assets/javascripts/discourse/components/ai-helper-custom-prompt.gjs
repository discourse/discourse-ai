import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import not from "truth-helpers/helpers/not";

export default class AiHelperCustomPrompt extends Component {
  @tracked _customPromptInput;

  @action
  setupCustomPrompt() {
    this._customPromptInput = document.querySelector(
      ".ai-custom-prompt__input"
    );
    this._customPromptInput.focus();
  }

  @action
  sendInput() {
    return this.args.submit(this.args.promptArgs);
  }

  <template>
    <div class="ai-custom-prompt" {{didInsert this.setupCustomPrompt}}>
      <Input
        @value={{@value}}
        placeholder={{i18n
          "discourse_ai.ai_helper.context_menu.custom_prompt.placeholder"
        }}
        class="ai-custom-prompt__input"
        @enter={{this.sendInput}}
      />

      <DButton
        @icon="discourse-sparkles"
        @action={{fn @submit @promptArgs}}
        @disabled={{not @value.length}}
        class="ai-custom-prompt__submit btn-primary"
      />
    </div>
  </template>
}
