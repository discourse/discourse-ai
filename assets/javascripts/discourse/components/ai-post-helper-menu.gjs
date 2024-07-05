import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { inject as service } from "@ember/service";
import { and } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import FastEdit from "discourse/components/fast-edit";
import FastEditModal from "discourse/components/modal/fast-edit";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { sanitize } from "discourse/lib/text";
import { clipboardCopy } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import eq from "truth-helpers/helpers/eq";
import AiHelperLoading from "../components/ai-helper-loading";
import AiHelperOptionsList from "../components/ai-helper-options-list";

export default class AiPostHelperMenu extends Component {
  @service messageBus;
  @service site;
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service menu;

  @tracked menuState = this.MENU_STATES.options;
  @tracked loading = false;
  @tracked suggestion = "";
  @tracked customPromptValue = "";
  @tracked copyButtonIcon = "copy";
  @tracked copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";
  @tracked showFastEdit = false;
  @tracked showAiButtons = true;
  @tracked streaming = false;
  @tracked lastSelectedOption = null;
  @tracked isSavingFootnote = false;

  MENU_STATES = {
    options: "OPTIONS",
    loading: "LOADING",
    result: "RESULT",
  };

  @tracked _activeAiRequest = null;

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

    if (!this.args.data.canEditPost) {
      prompts = prompts.filter((p) => p.name !== "proofread");
    }

    return prompts;
  }

  get highlightedTextToggleIcon() {
    if (this.showHighlightedText) {
      return "angle-double-left";
    } else {
      return "angle-double-right";
    }
  }

  get allowInsertFootnote() {
    const siteSettings = this.siteSettings;
    const canEditPost = this.args.data.canEditPost;

    if (
      !siteSettings?.enable_markdown_footnotes ||
      !siteSettings?.display_footnotes_inline ||
      !canEditPost
    ) {
      return false;
    }

    return this.lastSelectedOption?.name === "explain";
  }

  _showUserCustomPrompts() {
    return this.currentUser?.can_use_custom_prompts;
  }

  _sanitizeForFootnote(text) {
    // Remove line breaks (line-breaks breaks the inline footnote display)
    text = text.replace(/[\r\n]+/g, " ");

    // Remove headings (headings don't work in inline footnotes)
    text = text.replace(/^(#+)\s+/gm, "");

    // Trim excess space
    text = text.trim();

    return sanitize(text);
  }

  @bind
  subscribe() {
    const channel = `/discourse-ai/ai-helper/explain/${this.args.data.quoteState.postId}`;
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
    this.streaming = !result.done;
    this.suggestion = result.result;
  }

  @action
  toggleHighlightedTextPreview() {
    this.showHighlightedText = !this.showHighlightedText;
  }

  @action
  async performAiSuggestion(option) {
    this.menuState = this.MENU_STATES.loading;
    this.lastSelectedOption = option;

    if (option.name === "explain") {
      return this._handleExplainOption(option);
    } else {
      this._activeAiRequest = ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: option.id,
          text: this.args.data.quoteState.buffer,
          custom_prompt: this.customPromptValue,
        },
      });
    }

    this._activeAiRequest
      .then(({ suggestions }) => {
        this.suggestion = suggestions[0].trim();

        if (option.name === "proofread") {
          return this._handleProofreadOption();
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
        this.menuState = this.MENU_STATES.result;
      });

    return this._activeAiRequest;
  }

  _handleExplainOption(option) {
    this.menuState = this.MENU_STATES.result;
    const menu = this.menu.getByIdentifier("post-text-selection-toolbar");
    if (menu) {
      menu.options.placement = "bottom";
    }
    const fetchUrl = `/discourse-ai/ai-helper/explain`;

    this._activeAiRequest = ajax(fetchUrl, {
      method: "POST",
      data: {
        mode: option.value,
        text: this.args.data.selectedText,
        post_id: this.args.data.quoteState.postId,
      },
    });

    return this._activeAiRequest;
  }

  _handleProofreadOption() {
    this.showAiButtons = false;

    if (this.site.desktopView) {
      this.showFastEdit = true;
      return;
    } else {
      return this.modal.show(FastEditModal, {
        model: {
          initialValue: this.args.data.quoteState.buffer,
          newValue: this.suggestion,
          post: this.args.data.post,
          close: this.closeFastEdit,
        },
      });
    }
  }

  @action
  cancelAiAction() {
    if (this._activeAiRequest) {
      this._activeAiRequest.abort();
      this._activeAiRequest = null;
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

  @action
  closeMenu() {
    if (this.site.mobileView) {
      return this.args.close();
    }

    const menu = this.menu.getByIdentifier("post-text-selection-toolbar");
    return menu?.close();
  }

  @action
  async closeFastEdit() {
    this.showFastEdit = false;
    await this.args.data.hideToolbar();
  }

  @action
  async insertFootnote() {
    this.isSavingFootnote = true;

    if (this.allowInsertFootnote) {
      try {
        const result = await ajax(`/posts/${this.args.data.post.id}`);
        const sanitizedSuggestion = this._sanitizeForFootnote(this.suggestion);
        const credits = I18n.t(
          "discourse_ai.ai_helper.post_options_menu.footnote_credits"
        );
        const withFootnote = `${this.args.data.selectedText} ^[${sanitizedSuggestion} (${credits})]`;
        const newRaw = result.raw.replace(
          this.args.data.selectedText,
          withFootnote
        );

        await this.args.data.post.save({ raw: newRaw });
      } catch (error) {
        popupAjaxError(error);
      } finally {
        this.isSavingFootnote = false;
        await this.closeMenu();
      }
    }
  }

  <template>
    {{#if
      (and this.site.mobileView (eq this.menuState this.MENU_STATES.options))
    }}
      <div class="ai-post-helper-menu__selected-text">
        <h2>
          {{i18n "discourse_ai.ai_helper.post_options_menu.selected_text"}}
        </h2>
        <p>{{@data.selectedText}}</p>
      </div>
    {{/if}}

    {{#if this.showAiButtons}}
      <div class="ai-post-helper">
        {{#if (eq this.menuState this.MENU_STATES.options)}}
          <AiHelperOptionsList
            @options={{this.helperOptions}}
            @customPromptValue={{this.customPromptValue}}
            @performAction={{this.performAiSuggestion}}
          />
        {{else if (eq this.menuState this.MENU_STATES.loading)}}
          <AiHelperLoading @cancel={{this.cancelAiAction}} />
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
              <div class="ai-post-helper__suggestion__buttons">
                <DButton
                  @icon="times"
                  @label="discourse_ai.ai_helper.post_options_menu.cancel"
                  @action={{this.cancelAiAction}}
                  class="btn-flat ai-post-helper__suggestion__cancel"
                />
                <DButton
                  @icon={{this.copyButtonIcon}}
                  @label={{this.copyButtonLabel}}
                  @action={{this.copySuggestion}}
                  @disabled={{this.streaming}}
                  class="btn-flat ai-post-helper__suggestion__copy"
                />
                {{#if this.allowInsertFootnote}}
                  <DButton
                    @icon="asterisk"
                    @label="discourse_ai.ai_helper.post_options_menu.insert_footnote"
                    @action={{this.insertFootnote}}
                    @isLoading={{this.isSavingFootnote}}
                    @disabled={{this.streaming}}
                    class="btn-flat ai-post-helper__suggestion__insert-footnote"
                  />
                {{/if}}
              </div>
            {{else}}
              <AiHelperLoading @cancel={{this.cancelAiAction}} />
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if this.showFastEdit}}
      <div class="ai-post-helper__fast-edit">
        <FastEdit
          @initialValue={{@data.quoteState.buffer}}
          @newValue={{this.suggestion}}
          @post={{@data.post}}
          @close={{this.closeFastEdit}}
        />
      </div>
    {{/if}}
  </template>
}
