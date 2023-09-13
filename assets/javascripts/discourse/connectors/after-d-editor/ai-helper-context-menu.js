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
import showAIHelper from "../../lib/show-ai-helper";

export default class AiHelperContextMenu extends Component {
  static shouldRender(outletArgs, helper) {
    return showAIHelper(outletArgs, helper);
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
  @tracked lastUsedOption = null;
  @tracked showDiffModal = false;
  @tracked diff;
  @tracked popperPlacement = "top-start";

  CONTEXT_MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
    resets: "RESETS",
    loading: "LOADING",
    review: "REVIEW",
  };
  prompts = [];
  promptTypes = {};

  @tracked _popper;
  @tracked _dEditorInput;
  @tracked _contextMenu;
  @tracked _activeAIRequest = null;

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

    prompts
      .filter((p) => p.name !== "generate_titles")
      .map((p) => {
        this.prompts[p.id] = p;
      });

    this.promptTypes = prompts.reduce((memo, p) => {
      memo[p.name] = p.prompt_type;
      return memo;
    }, {});
    this.helperOptions = prompts
      .filter((p) => p.name !== "generate_titles")
      .map((p) => {
        return {
          name: p.translated_name,
          value: p.id,
        };
      });
  }

  @bind
  selectionChanged() {
    if (document.activeElement !== this._dEditorInput) {
      this.closeContextMenu();
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

    if (this.selectedText?.length === 0) {
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

  get canCloseContextMenu() {
    if (this.loading && this._activeAIRequest !== null) {
      return false;
    }

    if (this.menuState === this.CONTEXT_MENU_STATES.review) {
      return false;
    }

    return true;
  }

  closeContextMenu() {
    if (!this.canCloseContextMenu) {
      return;
    }

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

  _toggleLoadingState(loading) {
    if (loading) {
      this._dEditorInput.classList.add("loading");
      return (this.loading = true);
    }

    this._dEditorInput.classList.remove("loading");
    return (this.loading = false);
  }

  handleBoundaries() {
    const textAreaWrapper = document
      .querySelector(".d-editor-textarea-wrapper")
      .getBoundingClientRect();
    const buttonBar = document
      .querySelector(".d-editor-button-bar")
      .getBoundingClientRect();

    const boundaryElement = {
      top: buttonBar.bottom,
      bottom: textAreaWrapper.bottom,
    };

    const contextMenuRect = this._contextMenu.getBoundingClientRect();

    // Hide context menu if it's scrolled out of bounds:
    if (contextMenuRect.top < boundaryElement.top) {
      this._contextMenu.classList.add("out-of-bounds");
    } else if (contextMenuRect.bottom > boundaryElement.bottom) {
      this._contextMenu.classList.add("out-of-bounds");
    } else {
      this._contextMenu.classList.remove("out-of-bounds");
    }

    // Position context menu at based on if interfering with button bar
    if (this.caretCoords.y - contextMenuRect.height < boundaryElement.top) {
      this.popperPlacement = "bottom-start";
    } else {
      this.popperPlacement = "top-start";
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
      placement: this.popperPlacement,
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
    // context menu is prevented from closing when in review state
    // so we change to reset state quickly before closing
    this.menuState = this.CONTEXT_MENU_STATES.resets;
    this.closeContextMenu();
  }

  @action
  async updateSelected(option) {
    this._toggleLoadingState(true);
    this.lastUsedOption = option;
    this.menuState = this.CONTEXT_MENU_STATES.loading;

    this._activeAIRequest = ajax("/discourse-ai/ai-helper/suggest", {
      method: "POST",
      data: { mode: option, text: this.selectedText },
    });

    this._activeAIRequest
      .then((data) => {
        // resets the values if new suggestion is started:
        this.diff = null;
        this.newSelectedText = null;
        this._updateSuggestedByAI(data);
      })
      .catch(popupAjaxError)
      .finally(() => {
        this._toggleLoadingState(false);
      });

    return this._activeAIRequest;
  }

  @action
  viewChanges() {
    this.showDiffModal = true;
  }

  @action
  confirmChanges() {
    this.menuState = this.CONTEXT_MENU_STATES.resets;
  }

  @action
  cancelAIAction() {
    if (this._activeAIRequest) {
      this._activeAIRequest.abort();
      this._activeAIRequest = null;
      this._toggleLoadingState(false);
      this.closeContextMenu();
    }
  }
}
