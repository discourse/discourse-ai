import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";
import AiPersonaLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-persona-llm-selector";

export default RouteTemplate(
  <template>
    <div class="ai-bot-conversations">
      <AiPersonaLlmSelector
        @showLabels={{true}}
        @setPersonaId={{@controller.setPersonaId}}
        @setTargetRecipient={{@controller.setTargetRecipient}}
      />

      <div class="ai-bot-conversations__content-wrapper">
        <h1>{{i18n "discourse_ai.ai_bot.conversations.header"}}</h1>
        <PluginOutlet
          @name="ai-bot-conversations-above-input"
          @outletArgs={{hash
            updateInput=@controller.updateInputValue
            submit=@controller.aiBotConversationsHiddenSubmit.submitToBot
          }}
        />
        <div class="ai-bot-conversations__input-wrapper">
          <textarea
            {{didInsert @controller.setTextArea}}
            {{on "input" @controller.updateInputValue}}
            {{on "keydown" @controller.handleKeyDown}}
            id="ai-bot-conversations-input"
            autofocus="true"
            placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
            minlength="10"
            disabled={{@controller.loading}}
            rows="1"
          />
          <DButton
            @action={{@controller.aiBotConversationsHiddenSubmit.submitToBot}}
            @icon="paper-plane"
            @isLoading={{@controller.loading}}
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
