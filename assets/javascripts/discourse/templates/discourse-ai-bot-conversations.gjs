import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default RouteTemplate(
  <template>
    <div class="ai-bot-conversations">
      {{#if @controller.displayPersonaSelector}}
        <div class="ai-bot-conversations__persona-selector">
          <DropdownSelectBox
            class="persona-llm-selector__persona-dropdown"
            @value={{@controller.selectedPersona}}
            @valueProperty="username"
            @content={{@controller.personaOptions}}
            @options={{hash icon="robot" filterable=@controller.filterable}}
            @onChange={{@controller.selectedPersonaChanged}}
          />
        </div>
      {{/if}}

      <div class="ai-bot-conversations__content-wrapper">

        <h1>{{i18n "discourse_ai.ai_bot.conversations.header"}}</h1>
        <div class="ai-bot-conversations__input-wrapper">
          <textarea
            {{didInsert @controller.setTextArea}}
            {{on "input" @controller.updateInputValue}}
            {{on "keydown" @controller.handleKeyDown}}
            id="ai-bot-conversations-input"
            placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
            minlength="10"
            rows="1"
          />
          <DButton
            @action={{@controller.aiBotConversationsHiddenSubmit.submitToBot}}
            @icon="paper-plane"
            @title="discourse_ai.ai_bot.conversations.header"
            class="ai-bot-button btn-primary ai-conversation-submit"
          />
        </div>
        <p class="ai-disclaimer">
          {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
        </p>
      </div>
    </div>
  </template>
);
