import { tracked } from "@glimmer/tracking";
import { later } from "@ember/runloop";

const DEFAULT_WORD_TYPING_DELAY = 200;

/**
 * DiffStreamer provides a word-by-word animation effect for streamed diff updates.
 */
export default class DiffStreamer {
  @tracked isStreaming = false;
  @tracked words = [];
  @tracked lastResultText = "";
  @tracked diff = "";
  @tracked suggestion = "";
  @tracked isDone = false;
  @tracked isThinking = false;
  typingTimer = null;
  currentWordIndex = 0;

  /**
   * @param {string} selectedText - The original text to compare against.
   * @param {number} [typingDelay] - Delay in milliseconds between each word (ommitting this will use default delay).
   */
  constructor(selectedText, typingDelay) {
    this.selectedText = selectedText;
    this.typingDelay = typingDelay || DEFAULT_WORD_TYPING_DELAY;
  }

  /**
   * Updates the result with a newly streamed text chunk, computes new words,
   * and begins or continues streaming animation.
   *
   * @param {object} result - Object containing the updated text under the given key.
   * @param {string} newTextKey - The key where the updated suggestion text is found (e.g. if the JSON is { text: "Hello", done: false }, newTextKey would be "text")
   */
  async updateResult(result, newTextKey) {
    const newText = result[newTextKey];
    const diffText = newText.slice(this.lastResultText.length).trim();
    const newWords = diffText.split(/\s+/).filter(Boolean);
    this.isDone = result?.done;

    if (newWords.length > 0) {
      this.isStreaming = true;
      this.words.push(...newWords);
      if (!this.typingTimer) {
        this.#streamNextWord();
      }
    }

    this.lastResultText = newText;
  }

  /**
   * Resets the streamer to its initial state.
   */
  reset() {
    this.diff = null;
    this.suggestion = "";
    this.lastResultText = "";
    this.words = [];
    this.currentWordIndex = 0;
  }

  /**
   * Internal method to animate the next word in the queue and update the diff.
   *
   * Highlights the current word if streaming is ongoing.
   */
  #streamNextWord() {
    if (this.currentWordIndex === this.words.length && !this.isDone) {
      this.isThinking = true;
    }

    if (this.currentWordIndex === this.words.length && this.isDone) {
      this.isThinking = false;
      this.diff = this.#compareText(this.selectedText, this.suggestion, {
        markLastWord: false,
      });
      this.isStreaming = false;
    }

    if (this.currentWordIndex < this.words.length) {
      this.isThinking = false;
      this.suggestion += this.words[this.currentWordIndex] + " ";
      this.diff = this.#compareText(this.selectedText, this.suggestion, {
        markLastWord: true,
      });

      this.currentWordIndex++;
      this.typingTimer = later(this, this.#streamNextWord, this.typingDelay);
    } else {
      this.typingTimer = null;
    }
  }

  /**
   * Computes a simple word-level diff between the original and new text.
   * Inserts <ins> for inserted words, <del> for removed/replaced words,
   * and <mark> for the currently streaming word.
   *
   * @param {string} [oldText=""] - Original text.
   * @param {string} [newText=""] - Updated suggestion text.
   * @param {object} opts - Options for diff display.
   * @param {boolean} opts.markLastWord - Whether to highlight the last word.
   * @returns {string} - HTML string with diff markup.
   */
  #compareText(oldText = "", newText = "", opts = {}) {
    const oldWords = oldText.trim().split(/\s+/);
    const newWords = newText.trim().split(/\s+/);

    const diff = [];
    let i = 0;

    while (i < oldWords.length) {
      const oldWord = oldWords[i];
      const newWord = newWords[i];

      let wordHTML = "";
      let originalWordHTML = `<span class="ghost">${oldWord}</span>`;

      if (newWord === undefined) {
        wordHTML = originalWordHTML;
      } else if (oldWord === newWord) {
        wordHTML = `<span class="same-word">${newWord}</span>`;
      } else if (oldWord !== newWord) {
        wordHTML = `<del>${oldWord}</del> <ins>${newWord}</ins>`;
      }

      if (i === newWords.length - 1 && opts.markLastWord) {
        wordHTML = `<mark class="highlight">${wordHTML}</mark>`;
      }

      diff.push(wordHTML);
      i++;
    }

    return diff.join(" ");
  }
}
