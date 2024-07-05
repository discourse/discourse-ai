import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import eq from "truth-helpers/helpers/eq";
import AiHelperCustomPrompt from "../components/ai-helper-custom-prompt";

const AiHelperOptionsList = <template>
  <ul class="ai-helper-options">
    {{#each @options as |option|}}
      {{#if (eq option.name "custom_prompt")}}
        <AiHelperCustomPrompt
          @value={{@customPromptValue}}
          @promptArgs={{option}}
          @submit={{@performAction}}
        />
      {{else}}
        <li data-name={{option.translated_name}} data-value={{option.id}}>
          <DButton
            @icon={{option.icon}}
            @translatedLabel={{option.translated_name}}
            @action={{fn @performAction option}}
            data-name={{option.name}}
            data-value={{option.id}}
            class="btn-flat ai-helper-options__button"
          />
        </li>
      {{/if}}
    {{/each}}
  </ul>
</template>;

export default AiHelperOptionsList;
