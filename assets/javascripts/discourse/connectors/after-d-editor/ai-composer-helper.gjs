import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import { caretPosition, getCaretPosition } from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { afterRender, bind, debounce } from "discourse-common/utils/decorators";
import AiComposerHelperMenu from "../../components/ai-composer-helper-menu";
import { showComposerAIHelper } from "../../lib/show-ai-helper";
import virtualElementFromCaretCoords from "../../lib/virtual-element-from-caret-coords";

export default class AiComposerHelper extends Component {
  static shouldRender(outletArgs, helper) {
    return showComposerAIHelper(outletArgs, helper, "context_menu");
  }

  @service menu;
  @service aiComposerHelper;
  @tracked caretCoords;
  @tracked menuPlacement = "bottom-start";
  @tracked menuOffset = [9, 21];
  @tracked selectedText = "";
  @tracked isSelecting = false;
  @tracked menuElement = null;
  @tracked menuInstance = null;
  @tracked dEditorInput;
  @tracked selectionRange = { x: 0, y: 0 };
  minSelectionChars = 3;

  documentListeners = modifier(() => {
    document.addEventListener("mousedown", this.onMouseDown, { passive: true });
    document.addEventListener("mouseup", this.onMouseUp, { passive: true });
    document.addEventListener("selectionchange", this.onSelectionChanged);

    this.dEditorInput = document.querySelector(".d-editor-input");

    if (this.dEditorInput) {
      this.dEditorInput.addEventListener("scroll", this.updatePosition);
    }

    return () => {
      document.removeEventListener("mousedown", this.onMouseDown);
      document.removeEventListener("mouseup", this.onMouseUp);
      document.removeEventListener("selectionchange", this.onSelectionChanged);

      if (this.dEditorInput) {
        this.dEditorInput.removeEventListener("scroll", this.updatePosition);
      }
    };
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.menuInstance?.close();
  }

  @bind
  onSelectionChanged() {
    if (
      this.aiComposerHelper.menuState !==
      this.aiComposerHelper.MENU_STATES.triggers
    ) {
      return;
    }

    if (this.isSelecting) {
      return;
    }

    if (document.activeElement !== this.dEditorInput) {
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

    this.selectionRange = canSelect
      ? {
          x: document.activeElement.selectionStart,
          y: document.activeElement.selectionEnd,
        }
      : { x: 0, y: 0 };

    if (this.selectedText?.length === 0) {
      this.menuInstance?.close();
      return;
    }
    if (this.selectedText?.length < this.minSelectionChars) {
      return;
    }

    this.selectionChanged();
  }

  @debounce(INPUT_DELAY)
  selectionChanged() {
    this.positionMenu();
  }

  @bind
  onMouseDown() {
    this.isSelecting = true;
  }

  @bind
  onMouseUp() {
    this.isSelecting = false;
    this.onSelectionChanged();
  }

  @bind
  updatePosition() {
    if (!this.menuInstance) {
      return;
    }

    this.positionMenu();
  }

  @afterRender
  async positionMenu() {
    this.caretCoords = getCaretPosition(this.dEditorInput, {
      pos: caretPosition(this.dEditorInput),
    });
    const virtualElement = virtualElementFromCaretCoords(
      this.caretCoords,
      this.menuOffset
    );

    if (this.handleBoundaries(virtualElement)) {
      return;
    }

    // Position context menu at based on if interfering with button bar
    this.menuInstance = await this.menu.show(virtualElement, {
      identifier: "ai-composer-helper-menu",
      placement: this.menuPlacement,
      component: AiComposerHelperMenu,
      inline: true,
      modalForMobile: false,
      data: {
        selectedText: this.selectedText,
        dEditorInput: this.dEditorInput,
        selectionRange: this.selectionRange,
      },
      interactive: true,
      onClose: () => {
        this.aiComposerHelper.menuState =
          this.aiComposerHelper.MENU_STATES.triggers;
      },
    });
    this.menuElement = this.menuInstance.content;
  }

  handleBoundaries(virtualElement) {
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

    const menuHeightBuffer = 35; // rough estimate of menu height since we can't get actual in this context.
    if (this.caretCoords.y - menuHeightBuffer < boundaryElement.top) {
      this.menuPlacement = "bottom-start";
    } else {
      this.menuPlacement = "top-start";
    }

    if (this.isScrolledOutOfBounds(boundaryElement, virtualElement)) {
      this.menuInstance?.close();
      return true;
    }
  }

  isScrolledOutOfBounds(boundaryElement, virtualElement) {
    // Hide context menu if it's scrolled out of bounds:
    if (virtualElement.rect.top < boundaryElement.top) {
      return true;
    } else if (virtualElement.rect.bottom > boundaryElement.bottom) {
      return true;
    }

    return false;
  }

  <template>
    <div {{this.documentListeners}}></div>
  </template>
}
