import { cancel, later } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import Modifier from "ember-modifier";
import { cook } from "discourse/lib/text";

const STREAMED_TEXT_SPEED = 15;

export default class SmoothStreamTextModifier extends Modifier {
  typingTimer = null;
  displayedText = "";

  modify(element, [text, haltAnimation]) {
    if (haltAnimation) {
      return;
    }
    this._startTypingAnimation(element, text);
  }

  async _startTypingAnimation(element, text) {
    if (this.typingTimer) {
      cancel(this.typingTimer);
    }

    if (this.displayedText.length === 0) {
      element.innerHTML = "";
    }

    this._typeCharacter(element, text);
  }

  async _typeCharacter(element, text) {
    if (this.displayedText.length < text.length) {
      this.displayedText += text.charAt(this.displayedText.length);

      try {
        const cookedText = await cook(this.displayedText);
        element.classList.add("cooked");
        element.innerHTML = htmlSafe(cookedText);
      } catch (error) {
        console.error("Error cooking text during typing: ", error);
      }

      this.typingTimer = later(
        this,
        this._typeCharacter,
        element,
        text,
        STREAMED_TEXT_SPEED
      );
    } else {
      this.typingTimer = null;
    }
  }

  willRemove() {
    if (this.typingTimer) {
      cancel(this.typingTimer);
    }
  }
}
