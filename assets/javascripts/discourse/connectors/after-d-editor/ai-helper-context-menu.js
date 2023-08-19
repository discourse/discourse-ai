import Component from "@glimmer/component";
import { action } from "@ember/object";
import { bind, debounce } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { createPopper } from "@popperjs/core";
import { afterRender } from "discourse-common/utils/decorators";
import { next, schedule } from "@ember/runloop";
import {
  getCaretPosition,
  caretRowCol,
  caretPosition,
} from "discourse/lib/utilities";

export default class AiHelperContextMenu extends Component {
  @tracked helperOptions = [];
  @tracked showContextMenu = false;
  @tracked showContextMenuOptions = false;
  @tracked _popper;
  @tracked _dEditorInput;
  @tracked _contextMenu;
  @tracked caretCoords;
  @tracked virtualElement;
  @tracked selectedText = "";
  prompts = [];
  promptTypes = {};

  get showContextMenuTrigger() {
    return !this.showContextMenuOptions;
  }

  set showContextMenuTrigger(value) {
    this.showContextMenuOptions = !value;
  }

  resetContextMenuState() {
    this.showContextMenu = false;
    this.showContextMenuOptions = false;
  }

  constructor() {
    super(...arguments);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("selectionchange", this.selectionChanged);
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
  selectionChanged(event) {
    if (!event.target.activeElement.classList.contains("d-editor-input")) {
      return;
    }

    if (window.getSelection().toString().length === 0) {
      this.resetContextMenuState();
      return;
    }

    // TODO: Add approach for mobile
    this.selectedText = event.target.getSelection().toString();
    this._onSelectionChanged();
  }

  @bind
  updatePosition(event) {
    this.positionContextMenu();
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

  @afterRender
  positionContextMenu() {
    this._contextMenu = document.querySelector(".ai-helper-context-menu");
    this.caretCoords = getCaretPosition(this._dEditorInput, {
      pos: caretPosition(this._dEditorInput),
    });

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
    this.showContextMenuOptions = !this.showContextMenuOptions;
  }

  _updateSuggestedByAI(data) {
    // TODO others, just doing translate for now:
    // todo replace the text in the composer with the generated text
  }

  @action
  async updateSelected(option) {
    return ajax("/discourse-ai/ai-helper/suggest", {
      method: "POST",
      data: { mode: option, text: this.selectedText },
    })
      .then((data) => {
        const oldValue = this._dEditorInput.value;
        const newValue = oldValue.replace(
          this.selectedText,
          data.suggestions[0]
        );
        this._dEditorInput.value = newValue;
      })
      .catch(popupAjaxError)
      .finally(() => (this.loading = false));
  }
}

/*
 ! TODOS:
    - Add a settings.discourse_ai_enabled && settings.composer_ai_helper_enabled in shouldRender()
    - Add for each type
 */
