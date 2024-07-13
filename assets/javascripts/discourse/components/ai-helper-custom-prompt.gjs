import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import autoFocus from "discourse/modifiers/auto-focus";
import i18n from "discourse-common/helpers/i18n";
import not from "truth-helpers/helpers/not";

export default class AiHelperCustomPrompt extends Component {
  @action
  sendInput(event) {
    if (event.key !== "Enter") {
      return;
    }
    return this.args.submit(this.args.promptArgs);
  }

  <template>
    <div class="ai-custom-prompt">

      <input
        {{on "input" (withEventValue (fn (mut @value)))}}
        {{on "keydown" this.sendInput}}
        value={{@value}}
        placeholder={{i18n
          "discourse_ai.ai_helper.context_menu.custom_prompt.placeholder"
        }}
        class="ai-custom-prompt__input"
        type="text"
        {{!-- Using {{autoFocus}} helper instead of built in autofocus="autofocus" 
            because built in autofocus doesn't work consistently when component is
            invoked twice separetly without a page refresh. 
            (i.e. trigger in post AI helper followed by trigger in composer AI helper)
      --}}
        {{autoFocus}}
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
