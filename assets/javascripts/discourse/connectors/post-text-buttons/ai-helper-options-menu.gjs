import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import eq from "truth-helpers/helpers/eq";
import not from "truth-helpers/helpers/not";
import { inject as service } from "@ember/service";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { bind } from "discourse-common/utils/decorators";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AIHelperOptionsMenu extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }
  @service messageBus;
  @tracked helperOptions = [];
  @tracked menuState = this.MENU_STATES.triggers;
  @tracked loading = false;
  @tracked suggestion = "";
  @tracked showMainButtons = true;

  @tracked copyButtonIcon = "copy";
  @tracked copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";

  MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    loading: "LOADING",
    result: "RESULT",
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

  @bind
  subscribe() {
    console.log("messagebus subscribe", this.messageBus);
    const channel = `/discourse-ai/ai-helper/explain/${this.args.outletArgs.data.quoteState.postId}`;
    this.messageBus.subscribe(channel, this._updateResult);
  }

  @bind
  unsubscribe() {
    console.log("messagebus UNsubscribe");
    this.messageBus.unsubscribe("/discourse-ai/ai-helper/explain/*", this._updateResult);
  }

  @bind
  _updateResult(result) {
    console.log("this._updateResult called");
    console.log("_updateResult", result);
  }

  @action
  async performAISuggestion(option) {
    this.menuState = this.MENU_STATES.loading;

    if (option.name === "Explain") {
      this.menuState = this.MENU_STATES.result;
      const fetchUrl = `/discourse-ai/ai-helper/explain`;
      ajax(fetchUrl, {
        method: "POST",
        data: {
          mode: option.value,
          text: this.args.outletArgs.data.quoteState.buffer,
          post_id: this.args.outletArgs.data.quoteState.postId,
        }
      }).then((result) => {
        console.log("then called", result);
      }).catch((e) => console.log(e));
    }

    // if (option.name === "Explain") {
    //   this._activeAIRequest = ajax("/discourse-ai/ai-helper/explain?stream=true", {
    //     method: "POST",
    //     data: {
    //       mode: option.value,
    //       text: this.args.outletArgs.data.quoteState.buffer,
    //       post_id: this.args.outletArgs.data.quoteState.postId,
    //     },
    //   });
    // } else {
    //   this._activeAIRequest = ajax("/discourse-ai/ai-helper/suggest", {
    //     method: "POST",
    //     data: {
    //       mode: option.value,
    //       text: this.args.outletArgs.data.quoteState.buffer,
    //       custom_prompt: "",
    //     },
    //   });
    // }

    // this._activeAIRequest
    //   .then(({ suggestions }) => {
    //     console.log(suggestions);
    //     this.suggestion = suggestions[0];
    //   })
    //   .catch(popupAjaxError)
    //   .finally(() => {
    //     this.loading = false;
    //     this.menuState = this.MENU_STATES.result;
    //   });

    // return this._activeAIRequest;
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

  @action
  copySuggestion() {
    if (this.suggestion?.length > 0) {
      navigator.clipboard.writeText(this.suggestion).then(() => {
        this.copyButtonIcon = "check";
        this.copyButtonLabel =
          "discourse_ai.ai_helper.post_options_menu.copied";
        setTimeout(() => {
          this.copyButtonIcon = "copy";
          this.copyButtonLabel =
            "discourse_ai.ai_helper.post_options_menu.copy";
        }, 3500);
      });
    }
  }

  async loadPrompts() {
    let prompts = await ajax("/discourse-ai/ai-helper/prompts");

    this.helperOptions = prompts
      .filter((item) => item.location.includes("post"))
      .map((p) => {
        return {
          name: p.translated_name,
          value: p.id,
          icon: p.icon,
        };
      });
  }

  <template>
    {{#if this.showMainButtons}}
      {{yield}}
    {{/if}}
    <div class="ai-post-helper">
      {{#if (eq this.menuState this.MENU_STATES.triggers)}}
        <DButton
          @class="btn-flat ai-post-helper__trigger"
          @icon="discourse-sparkles"
          @title="discourse_ai.ai_helper.post_options_menu.title"
          @label="discourse_ai.ai_helper.post_options_menu.trigger"
          @action={{this.showAIHelperOptions}}
        />

      {{else if (eq this.menuState this.MENU_STATES.options)}}
        <div class="ai-post-helper__options">
          {{#each this.helperOptions as |option|}}
            <DButton
              @class="btn-flat"
              @icon={{option.icon}}
              @translatedLabel={{option.name}}
              @action={{this.performAISuggestion}}
              @actionParam={{option}}
              data-name={{option.name}}
              data-value={{option.value}}
            />
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
        <div class="ai-post-helper__suggestion" {{didInsert this.subscribe}} {{willDestroy this.unsubscribe}}>
          <div class="ai-post-helper__suggestion__text">
            {{this.suggestion}}
          </div>
          <DButton
            @class="btn-flat ai-post-helper__suggestion__copy"
            @icon={{this.copyButtonIcon}}
            @label={{this.copyButtonLabel}}
            @action={{this.copySuggestion}}
            @disabled={{not this.suggestion}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
