import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import AiHelperButtonGroup from "../components/ai-helper-button-group";
import AiHelperLoading from "../components/ai-helper-loading";
import AiHelperOptionsList from "../components/ai-helper-options-list";
import ModalDiffModal from "../components/modal/diff-modal";
import ThumbnailSuggestion from "../components/modal/thumbnail-suggestions";

export default class AiComposerHelperMenu extends Component {
  @service siteSettings;
  @service aiComposerHelper;
  @service currentUser;
  @service capabilities;
  @tracked newSelectedText;
  @tracked diff;
  @tracked initialValue = "";
  @tracked customPromptValue = "";
  @tracked loading = false;
  @tracked lastUsedOption = null;
  @tracked thumbnailSuggestions = null;
  @tracked showThumbnailModal = false;
  @tracked showDiffModal = false;
  @tracked lastSelectionRange = null;
  MENU_STATES = this.aiComposerHelper.MENU_STATES;
  prompts = [];
  promptTypes = {};

  documentListeners = modifier(() => {
    document.addEventListener("keydown", this.onKeyDown, { passive: true });

    return () => {
      document.removeEventListener("keydown", this.onKeyDown);
    };
  });

  get helperOptions() {
    let prompts = this.currentUser?.ai_helper_prompts;

    prompts = prompts
      .filter((p) => p.location.includes("composer"))
      .filter((p) => p.name !== "generate_titles")
      .map((p) => {
        // AI helper by default returns interface locale on translations
        // Since we want site default translations (and we are using: force_default_locale)
        // we need to replace the translated_name with the site default locale name
        const siteLocale = this.siteSettings.default_locale;
        const availableLocales = JSON.parse(
          this.siteSettings.available_locales
        );
        const locale = availableLocales.find((l) => l.value === siteLocale);
        const translatedName = I18n.t(
          "discourse_ai.ai_helper.context_menu.translate_prompt",
          {
            language: locale.name,
          }
        );

        if (p.name === "translate") {
          return { ...p, translated_name: translatedName };
        }
        return p;
      });

    // Find the custom_prompt object and move it to the beginning of the array
    const customPromptIndex = prompts.findIndex(
      (p) => p.name === "custom_prompt"
    );
    if (customPromptIndex !== -1) {
      const customPrompt = prompts.splice(customPromptIndex, 1)[0];
      prompts.unshift(customPrompt);
    }

    if (!this.currentUser?.can_use_custom_prompts) {
      prompts = prompts.filter((p) => p.name !== "custom_prompt");
    }

    prompts.forEach((p) => {
      this.prompts[p.id] = p;
    });

    this.promptTypes = prompts.reduce((memo, p) => {
      memo[p.name] = p.prompt_type;
      return memo;
    }, {});
    return prompts;
  }

  get reviewButtons() {
    return [
      {
        icon: "exchange-alt",
        label: "discourse_ai.ai_helper.context_menu.view_changes",
        action: () => (this.showDiffModal = true),
        classes: "view-changes",
      },
      {
        icon: "undo",
        label: "discourse_ai.ai_helper.context_menu.revert",
        action: this.undoAiAction,
        classes: "revert",
      },
      {
        icon: "check",
        label: "discourse_ai.ai_helper.context_menu.confirm",
        action: () => this.updateMenuState(this.MENU_STATES.resets),
        classes: "confirm",
      },
    ];
  }

  get resetButtons() {
    return [
      {
        icon: "undo",
        label: "discourse_ai.ai_helper.context_menu.undo",
        action: this.undoAiAction,
        classes: "undo",
      },
      {
        icon: "discourse-sparkles",
        label: "discourse_ai.ai_helper.context_menu.regen",
        action: () => this.updateSelected(this.lastUsedOption),
        classes: "regenerate",
      },
    ];
  }

  get canCloseMenu() {
    if (
      document.activeElement ===
      document.querySelector(".ai-custom-prompt__input")
    ) {
      return false;
    }

    if (this.loading && this._activeAiRequest !== null) {
      return false;
    }

    if (this.aiComposerHelper.menuState === this.MENU_STATES.review) {
      return false;
    }

    return true;
  }

  @bind
  onKeyDown(event) {
    if (event.key === "Escape") {
      return this.closeMenu();
    }
    if (
      event.key === "Backspace" &&
      this.args.data.selectedText &&
      this.aiComposerHelper.menuState === this.MENU_STATES.triggers
    ) {
      return this.closeMenu();
    }
  }

  @action
  toggleAiHelperOptions() {
    this.updateMenuState(this.MENU_STATES.options);
  }

  @action
  async updateSelected(option) {
    this._toggleLoadingState(true);
    this.lastUsedOption = option;
    this.updateMenuState(this.MENU_STATES.loading);
    this.initialValue = this.args.data.selectedText;
    this.lastSelectionRange = this.args.data.selectionRange;

    try {
      this._activeAiRequest = await ajax("/discourse-ai/ai-helper/suggest", {
        method: "POST",
        data: {
          mode: option.id,
          text: this.args.data.selectedText,
          custom_prompt: this.customPromptValue,
          force_default_locale: true,
        },
      });

      const data = await this._activeAiRequest;

      // resets the values if new suggestion is started:
      this.diff = null;
      this.newSelectedText = null;
      this.thumbnailSuggestions = null;

      if (option.name === "illustrate_post") {
        this._toggleLoadingState(false);
        this.closeMenu();
        this.showThumbnailModal = true;
        this.thumbnailSuggestions = data.thumbnails;
      } else {
        this._updateSuggestedByAi(data);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this._toggleLoadingState(false);
    }

    return this._activeAiRequest;
  }

  @action
  cancelAiAction() {
    if (this._activeAiRequest) {
      this._activeAiRequest.abort();
      this._activeAiRequest = null;
      this._toggleLoadingState(false);
      this.closeMenu();
    }
  }

  @action
  updateMenuState(newState) {
    this.aiComposerHelper.menuState = newState;
  }

  @action
  closeMenu() {
    if (!this.canCloseMenu) {
      return;
    }

    this.customPromptValue = "";
    this.updateMenuState(this.MENU_STATES.triggers);
    this.args.close();
  }

  @action
  undoAiAction() {
    if (this.capabilities.isFirefox) {
      // execCommand("undo") is no not supported in Firefox so we insert old text at range
      // we also need to calculate the length diffrence between the old and new text
      const lengthDifference =
        this.args.data.selectedText.length - this.initialValue.length;
      const end = this.lastSelectionRange.y - lengthDifference;
      this._insertAt(this.lastSelectionRange.x, end, this.initialValue);
    } else {
      document.execCommand("undo", false, null);
    }

    // context menu is prevented from closing when in review state
    // so we change to reset state quickly before closing
    this.updateMenuState(this.MENU_STATES.resets);
    this.closeMenu();
  }

  _toggleLoadingState(loading) {
    if (loading) {
      this.args.data.dEditorInput.classList.add("loading");
      return (this.loading = true);
    }

    this.args.data.dEditorInput.classList.remove("loading");
    this.loading = false;
  }

  _updateSuggestedByAi(data) {
    this.newSelectedText = data.suggestions[0];

    if (data.diff) {
      this.diff = data.diff;
    }

    this._insertAt(
      this.args.data.selectionRange.x,
      this.args.data.selectionRange.y,
      this.newSelectedText
    );

    this.updateMenuState(this.MENU_STATES.review);
  }

  _insertAt(start, end, text) {
    this.args.data.dEditorInput.setSelectionRange(start, end);
    this.args.data.dEditorInput.focus();
    document.execCommand("insertText", false, text);
  }

  <template>
    <div class="ai-composer-helper-menu" {{this.documentListeners}}>
      {{#if (eq this.aiComposerHelper.menuState this.MENU_STATES.triggers)}}
        <ul class="ai-composer-helper-menu__triggers">
          <li>
            <DButton
              @icon="discourse-sparkles"
              @label="discourse_ai.ai_helper.context_menu.trigger"
              @action={{this.toggleAiHelperOptions}}
              class="btn-flat"
            />
          </li>
        </ul>
      {{else if (eq this.aiComposerHelper.menuState this.MENU_STATES.options)}}
        <AiHelperOptionsList
          @options={{this.helperOptions}}
          @customPromptValue={{this.customPromptValue}}
          @performAction={{this.updateSelected}}
        />
      {{else if (eq this.aiComposerHelper.menuState this.MENU_STATES.loading)}}
        <AiHelperLoading @cancel={{this.cancelAiAction}} />
      {{else if (eq this.aiComposerHelper.menuState this.MENU_STATES.review)}}
        <AiHelperButtonGroup
          @buttons={{this.reviewButtons}}
          class="ai-composer-helper-menu__review"
        />
      {{else if (eq this.aiComposerHelper.menuState this.MENU_STATES.resets)}}
        <AiHelperButtonGroup
          @buttons={{this.resetButtons}}
          class="ai-composer-helper-menu__resets"
        />
      {{/if}}
    </div>

    {{#if this.showDiffModal}}
      <ModalDiffModal
        @confirm={{fn
          (mut this.aiComposerHelper.menuState)
          this.MENU_STATES.resets
        }}
        @diff={{this.diff}}
        @oldValue={{this.initialValue}}
        @newValue={{this.newSelectedText}}
        @revert={{this.undoAiAction}}
        @closeModal={{fn (mut this.showDiffModal) false}}
      />
    {{/if}}

    {{#if this.showThumbnailModal}}
      <ThumbnailSuggestion
        @thumbnails={{this.thumbnailSuggestions}}
        @closeModal={{fn (mut this.showThumbnailModal) false}}
      />
    {{/if}}
  </template>
}
