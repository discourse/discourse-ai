import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { and } from "truth-helpers";
import DButton from "discourse/components/d-button";
import eq from "truth-helpers/helpers/eq";
import AiHelperCustomPrompt from "../components/ai-helper-custom-prompt";

export default class AiHelperOptionsList extends Component {
  @service site;

  get showShortcut() {
    return this.site.desktopView && this.args.shortcutVisible;
  }

  <template>
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
              class="ai-helper-options__button"
            >
              {{#if (and (eq option.name "proofread") this.showShortcut)}}
                <kbd class="shortcut">⌘⌥p</kbd>
              {{/if}}
            </DButton>
          </li>
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
