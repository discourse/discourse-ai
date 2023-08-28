import Component from "@glimmer/component";
import { action } from "@ember/object";
import { afterRender, bind, debounce } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createPopper } from "@popperjs/core";
import { caretPosition, getCaretPosition } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class AiHelperContextMenu extends Component {
  static shouldRender(outletArgs, helper) {
    const helperEnabled =
      helper.siteSettings.discourse_ai_enabled &&
      helper.siteSettings.composer_ai_helper_enabled;

    const allowedGroups = helper.siteSettings.ai_helper_allowed_groups
      .split("|")
      .map((id) => parseInt(id, 10));
    const canUseAssistant = helper.currentUser?.groups.some((g) =>
      allowedGroups.includes(g.id)
    );

    const canShowInPM = helper.siteSettings.ai_helper_allowed_in_pm;

    if (outletArgs?.composer?.privateMessage) {
      return helperEnabled && canUseAssistant && canShowInPM;
    }

    return helperEnabled && canUseAssistant;
  }

  @service siteSettings;
  @tracked helperOptions = [];
  @tracked showContextMenu = false;
  @tracked menuState = this.CONTEXT_MENU_STATES.triggers;
  @tracked caretCoords;
  @tracked virtualElement;
  @tracked selectedText = "";
  @tracked newSelectedText;
  @tracked loading = false;
  @tracked oldEditorValue;
  @tracked newEditorValue;
  @tracked generatedTitleSuggestions = [];
  @tracked lastUsedOption = null;
  @tracked showDiffModal = false;
  @tracked diff;

  CONTEXT_MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    resets: "RESETS",
    loading: "LOADING",
    suggesions: "SUGGESTIONS",
    review: "REVIEW",
  };
  prompts = [];
  promptTypes = {};

  @tracked _popper;
  @tracked _dEditorInput;
  @tracked _contextMenu;

  constructor() {
    super(...arguments);

    // Fetch prompts only if it hasn't been fetched yet
    if (this.helperOptions.length === 0) {
      this.loadPrompts();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("selectionchange", this.selectionChanged);
    document.removeEventListener("keydown", this.onKeyDown);
    this._popper?.destroy();
  }

  async loadPrompts() {
    let prompts = await ajax("/discourse-ai/ai-helper/prompts");

    prompts.map((p) => {
      this.prompts[p.id] = p;
    });

    this.promptTypes = prompts.reduce((memo, p) => {
      memo[p.name] = p.prompt_type;
      return memo;
    }, {});

    this.helperOptions = prompts.map((p) => {
      return {
        name: p.translated_name,
        value: p.id,
      };
    });
  }

  @bind
  selectionChanged() {
    if (document.activeElement !== this._dEditorInput) {
      return;
    }

    const canSelect = Boolean(
      window.getSelection() &&
        document.activeElement &&
        document.activeElement.value
    );

    this.selectedText = canSelect
      ? document.activeElement.value.substring(
          document.activeElement.selectionStart,
          document.activeElement.selectionEnd
        )
      : "";

    if (this.selectedText.length === 0) {
      if (this.loading || this.menuState === this.CONTEXT_MENU_STATES.review) {
        // prevent accidentally closing context menu
        // while results loading or in review state
        return;
      }

      this.closeContextMenu();
      return;
    }

    this._onSelectionChanged();
  }

  @bind
  updatePosition() {
    if (!this.showContextMenu) {
      return;
    }

    this.positionContextMenu();
  }

  @bind
  onKeyDown(event) {
    const cmdOrCtrl = event.ctrlKey || event.metaKey;

    if (cmdOrCtrl && event.key === "z" && this.oldEditorValue) {
      return this.undoAIAction();
    }

    if (event.key === "Escape") {
      return this.closeContextMenu();
    }
  }

  @debounce(INPUT_DELAY)
  _onSelectionChanged() {
    this.positionContextMenu();
    this.showContextMenu = true;
  }

  generateGetBoundingClientRect(width = 0, height = 0, x = 0, y = 0) {
    return () => ({
      width,
      height,
      top: y,
      right: x,
      bottom: y,
      left: x,
    });
  }

  closeContextMenu() {
    this.showContextMenu = false;
    this.menuState = this.CONTEXT_MENU_STATES.triggers;
  }

  _updateSuggestedByAI(data) {
    const composer = this.args.outletArgs.composer;
    this.oldEditorValue = this._dEditorInput.value;
    this.newSelectedText = data.suggestions[0];

    this.newEditorValue = this.oldEditorValue.replace(
      this.selectedText,
      this.newSelectedText
    );

    if (data.diff) {
      this.diff = data.diff;
    }
    composer.set("reply", this.newEditorValue);
    this.menuState = this.CONTEXT_MENU_STATES.review;
  }

  handleBoundaries() {
    const boundaryElement = document
      .querySelector(".d-editor-textarea-wrapper")
      .getBoundingClientRect();

    const contextMenuRect = this._contextMenu.getBoundingClientRect();

    if (contextMenuRect.top < boundaryElement.top) {
      this._contextMenu.classList.add("out-of-bounds");
    } else if (contextMenuRect.bottom > boundaryElement.bottom) {
      this._contextMenu.classList.add("out-of-bounds");
    } else {
      this._contextMenu.classList.remove("out-of-bounds");
    }
  }

  @afterRender
  positionContextMenu() {
    this._contextMenu = document.querySelector(".ai-helper-context-menu");
    this.caretCoords = getCaretPosition(this._dEditorInput, {
      pos: caretPosition(this._dEditorInput),
    });

    // prevent overflow of context menu outside of editor
    this.handleBoundaries();

    this.virtualElement = {
      getBoundingClientRect: this.generateGetBoundingClientRect(
        this._contextMenu.clientWidth,
        this._contextMenu.clientHeight,
        this.caretCoords.x,
        this.caretCoords.y
      ),
    };

    this._popper = createPopper(this.virtualElement, this._contextMenu, {
      placement: "top-start",
      modifiers: [
        {
          name: "offset",
          options: {
            offset: [10, 0],
          },
        },
      ],
    });
  }

  @action
  setupContextMenu() {
    document.addEventListener("selectionchange", this.selectionChanged);
    document.addEventListener("keydown", this.onKeyDown);

    this._dEditorInput = document.querySelector(".d-editor-input");

    if (this._dEditorInput) {
      this._dEditorInput.addEventListener("scroll", this.updatePosition);
    }
  }

  @action
  toggleAiHelperOptions() {
    // Fetch prompts only if it hasn't been fetched yet
    if (this.helperOptions.length === 0) {
      this.loadPrompts();
    }
    this.menuState = this.CONTEXT_MENU_STATES.options;
  }

  @action
  undoAIAction() {
    const composer = this.args.outletArgs.composer;
    composer.set("reply", this.oldEditorValue);
    this.closeContextMenu();
  }

  @action
  async updateSelected(option) {
    this.loading = true;
    this.lastUsedOption = option;
    this._dEditorInput.classList.add("loading");
    this.menuState = this.CONTEXT_MENU_STATES.loading;

    return ajax("/discourse-ai/ai-helper/suggest", {
      method: "POST",
      data: { mode: option, text: this.selectedText },
    })
      .then((data) => {
        // resets the values if new suggestion is started:
        this.diff = null;
        this.newSelectedText = null;

        if (this.prompts[option].name === "generate_titles") {
          this.menuState = this.CONTEXT_MENU_STATES.suggestions;
          this.generatedTitleSuggestions = data.suggestions;
        } else {
          this._updateSuggestedByAI(data);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
        this._dEditorInput.classList.remove("loading");
      });
  }

  @action
  updateTopicTitle(title) {
    const composer = this.args.outletArgs?.composer;

    if (composer) {
      composer.set("title", title);
      this.closeContextMenu();
    }
  }

  @action
  viewChanges() {
    this.showDiffModal = true;
  }

  @action
  confirmChanges() {
    this.menuState = this.CONTEXT_MENU_STATES.resets;
  }
}
