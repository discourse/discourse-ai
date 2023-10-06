import Component from '@glimmer/component';
import DButton from "discourse/components/d-button";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import showAIHelper from "../../lib/show-ai-helper";
import eq from "truth-helpers/helpers/eq";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

const i18n = I18n.t.bind(I18n);

export default class AIHelperOptionsMenu extends Component {
  <template>
    {{#if this.showMainButtons}}
      {{yield}}
    {{/if}}
    <div class="ai-post-helper">
    {{#if (eq this.menuState this.MENU_STATES.triggers)}}
      <DButton @class="btn-flat" @icon="discourse-sparkles" @label="discourse_ai.ai_helper.post_options_menu.trigger" @action={{this.showAIHelperOptions}} />

    {{else if (eq this.menuState this.MENU_STATES.options)}}
      <div class="ai-post-helper__options">
      {{#each this.helperOptions as |option|}}
        <DButton @class="btn-flat" @icon={{option.icon}} @translatedLabel={{option.name}} @action={{this.performAISuggestion}} @actionParam={{option}} />
      {{/each}}
      </div>

    {{else if (eq this.menuState this.MENU_STATES.loading)}}
      <div class="ai-helper-context-menu__loading">
        <div class="dot-falling"></div>
        <span>
          {{i18n "discourse_ai.ai_helper.context_menu.loading"}}
        </span>
        <DButton
          @icon="times"
          @title="discourse_ai.ai_helper.context_menu.cancel"
          @action={{this.cancelAIAction}}
          class="btn-flat cancel-request"
        />
      </div>
    {{else if (eq this.menuState this.MENU_STATES.result)}}
      <div class="ai-post-helper__suggestion">{{this.suggestion}}</div>
    {{/if}}
    </div>
  </template>

  static shouldRender(outletArgs, helper) {
    return showAIHelper(outletArgs, helper);
  }
  @tracked helperOptions = [];
  @tracked menuState = this.MENU_STATES.triggers;
  @tracked loading = false;
  @tracked suggestion = "";
  @tracked showMainButtons = true;

  MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    loading: "LOADING",
    result: "RESULT"
  };

  @tracked _activeAIRequest = null;


  constructor() {
    super(...arguments);

    if (this.helperOptions.length === 0) {
      this.loadPrompts();
    }
  }

  @action
  async showAIHelperOptions() {
    this.showMainButtons = false;
    this.menuState = this.MENU_STATES.options;
  }

  @action
  async performAISuggestion(option) {
    this.menuState = this.MENU_STATES.loading;

    this._activeAIRequest = ajax("/discourse-ai/ai-helper/suggest", {
      method: "POST",
      data: {
        mode: option.value,
        text: this.args.outletArgs.data.quoteState.buffer,
        custom_prompt: "",
      }
    });

    this._activeAIRequest.then(({ suggestions }) => {
      this.suggestion = suggestions[0];
    }).catch(popupAjaxError).finally(() => {
      this.loading = false;
      this.menuState = this.MENU_STATES.result;
    });

    return this._activeAIRequest;
  }

  @action
  cancelAIAction() {
    if (this._activeAIRequest) {
      this._activeAIRequest.abort();
      this._activeAIRequest = null;
      this.loading = false;
      this.menuState = this.MENU_STATES.options;
    }
  }

  async loadPrompts() {
    let prompts = await ajax("/discourse-ai/ai-helper/prompts");

    const promptsToRemove = ["generate_titles", "markdown_table", "custom_prompt"];

    this.helperOptions = prompts.filter(item => !promptsToRemove.includes(item.name)).map((p) => {
      return {
        name: p.translated_name,
        value: p.id,
        icon: p.icon,
      };
    });
  }
}