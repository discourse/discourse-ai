import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { inject as service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import FastEdit from "discourse/components/fast-edit";
import FastEditModal from "discourse/components/modal/fast-edit";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { bind } from "discourse-common/utils/decorators";
import eq from "truth-helpers/helpers/eq";
import not from "truth-helpers/helpers/not";
import AiHelperCustomPrompt from "../../components/ai-helper-custom-prompt";
import AiHelperLoading from "../../components/ai-helper-loading";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AIHelperOptionsMenu extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }

  @service messageBus;
  @service site;
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service menu;

  @tracked menuState = this.MENU_STATES.triggers;
  @tracked loading = false;
  @tracked suggestion = "";
  @tracked showMainButtons = true;
  @tracked customPromptValue = "";
  @tracked copyButtonIcon = "copy";
  @tracked copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";
  @tracked showFastEdit = false;
  @tracked showAiButtons = true;

  MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    loading: "LOADING",
    result: "RESULT",
  };

  @tracked _activeAIRequest = null;

  @action
  async showAIHelperOptions() {
    this.showMainButtons = false;
    this.menuState = this.MENU_STATES.options;
    this.menu.activeMenu.options.placement = "bottom";
  }

  @bind
  subscribe() {
    const channel = `/discourse-ai/ai-helper/explain/${this.args.outletArgs.data.quoteState.postId}`;
    this.messageBus.subscribe(channel, this._updateResult);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe(
      "/discourse-ai/ai-helper/explain/*",
      this._updateResult
    );
  }

  @bind
  _updateResult(result) {
    this.suggestion = result.result;
  }

  @action
  async performAISuggestion(option) {
    this.menuState = this.MENU_STATES.loading;

    if (option.name === "explain") {
      this.menuState = this.MENU_STATES.result;

      const fetchUrl = `/discourse-ai/ai-helper/explain`;
      this._activeAIRequest = ajax(fetchUrl, {
        method: "POST",
        data: {
          mode: option.value,
          text: this.args.outletArgs.data.quoteState.buffer,
          post_id: this.args.outletArgs.data.quoteState.postId,
        },
      });
    } else {
      this._activeAIRequest = ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: option.id,
          text: this.args.outletArgs.data.quoteState.buffer,
          custom_prompt: this.customPromptValue,
        },
      });
    }

    if (option.name !== "explain") {
      this._activeAIRequest
        .then(({ suggestions }) => {
          this.suggestion = suggestions[0].trim();

          if (option.name === "proofread") {
            this.showAiButtons = false;

            if (this.site.desktopView) {
              this.showFastEdit = true;
              return;
            } else {
              return this.modal.show(FastEditModal, {
                model: {
                  initialValue: this.args.outletArgs.data.quoteState.buffer,
                  newValue: this.suggestion,
                  post: this.args.outletArgs.post,
                  close: this.closeFastEdit,
                },
              });
            }
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.loading = false;
          this.menuState = this.MENU_STATES.result;
        });
    }

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

  @action
  copySuggestion() {
    if (this.suggestion?.length > 0) {
      clipboardCopy(this.suggestion);
      this.copyButtonIcon = "check";
      this.copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copied";
      setTimeout(() => {
        this.copyButtonIcon = "copy";
        this.copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";
      }, 3500);
    }
  }

  get helperOptions() {
    let prompts = this.currentUser?.ai_helper_prompts;

    prompts = prompts.filter((item) => item.location.includes("post"));

    // Find the custom_prompt object and move it to the beginning of the array
    const customPromptIndex = prompts.findIndex(
      (p) => p.name === "custom_prompt"
    );

    if (customPromptIndex !== -1) {
      const customPrompt = prompts.splice(customPromptIndex, 1)[0];
      prompts.unshift(customPrompt);
    }

    if (!this._showUserCustomPrompts()) {
      prompts = prompts.filter((p) => p.name !== "custom_prompt");
    }

    if (!this.args.outletArgs.data.canEditPost) {
      prompts = prompts.filter((p) => p.name !== "proofread");
    }

    return prompts;
  }

  _showUserCustomPrompts() {
    return this.currentUser?.can_use_custom_prompts;
  }

  @action
  async closeFastEdit() {
    this.showFastEdit = false;
    await this.args.outletArgs.data.hideToolbar();
  }

  <template>
    {{#if this.showMainButtons}}
      {{yield}}
    {{/if}}

    {{#if this.showAiButtons}}
      <div class="ai-post-helper">
        {{#if (eq this.menuState this.MENU_STATES.triggers)}}
          <DButton
            @icon="discourse-sparkles"
            @title="discourse_ai.ai_helper.post_options_menu.title"
            @label="discourse_ai.ai_helper.post_options_menu.trigger"
            @action={{this.showAIHelperOptions}}
            class="btn-flat ai-post-helper__trigger"
          />

        {{else if (eq this.menuState this.MENU_STATES.options)}}
          <div class="ai-post-helper__options">
            {{#each this.helperOptions as |option|}}
              {{#if (eq option.name "custom_prompt")}}
                <AiHelperCustomPrompt
                  @value={{this.customPromptValue}}
                  @promptArgs={{option}}
                  @submit={{this.performAISuggestion}}
                />
              {{else}}
                <DButton
                  @icon={{option.icon}}
                  @translatedLabel={{option.translated_name}}
                  @action={{fn this.performAISuggestion option}}
                  data-name={{option.name}}
                  data-value={{option.id}}
                  class="btn-flat ai-post-helper__options-button"
                />
              {{/if}}
            {{/each}}
          </div>

        {{else if (eq this.menuState this.MENU_STATES.loading)}}
          <AiHelperLoading @cancel={{this.cancelAIAction}} />
        {{else if (eq this.menuState this.MENU_STATES.result)}}
          <div
            class="ai-post-helper__suggestion"
            {{didInsert this.subscribe}}
            {{willDestroy this.unsubscribe}}
          >
            {{#if this.suggestion}}
              <div class="ai-post-helper__suggestion__text" dir="auto">
                <CookText @rawText={{this.suggestion}} />
              </div>
              <di class="ai-post-helper__suggestion__buttons">
                <DButton
                  @icon="times"
                  @label="discourse_ai.ai_helper.post_options_menu.cancel"
                  @action={{this.cancelAIAction}}
                  class="btn-flat ai-post-helper__suggestion__cancel"
                />
                <DButton
                  @icon={{this.copyButtonIcon}}
                  @label={{this.copyButtonLabel}}
                  @action={{this.copySuggestion}}
                  @disabled={{not this.suggestion}}
                  class="btn-flat ai-post-helper__suggestion__copy"
                />
              </di>
            {{else}}
              <AiHelperLoading @cancel={{this.cancelAIAction}} />
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if this.showFastEdit}}
      <div class="ai-post-helper__fast-edit">
        <FastEdit
          @initialValue={{@outletArgs.data.quoteState.buffer}}
          @newValue={{this.suggestion}}
          @post={{@outletArgs.post}}
          @close={{this.closeFastEdit}}
        />
      </div>
    {{/if}}
  </template>
}
