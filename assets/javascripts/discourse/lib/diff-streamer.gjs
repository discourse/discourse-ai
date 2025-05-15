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

    // Track where the line breaks are in the original oldText
    const lineBreakMap = (() => {
      const lines = oldText.trim().split("\n");
      const map = new Set();
      let wordIndex = 0;

      for (const line of lines) {
        const wordsInLine = line.trim().split(/\s+/);
        wordIndex += wordsInLine.length;
        map.add(wordIndex - 1); // Mark the last word in each line
      }

      return map;
    })();

    const diff = [];
    let i = 0;

    while (i < oldWords.length || i < newWords.length) {
      const oldWord = oldWords[i];
      const newWord = newWords[i];

      let wordHTML = "";

      if (newWord === undefined) {
        wordHTML = `<span class="ghost">${oldWord}</span>`;
      } else if (oldWord === newWord) {
        wordHTML = `<span class="same-word">${newWord}</span>`;
      } else if (oldWord !== newWord) {
        wordHTML = `<del>${oldWord ?? ""}</del> <ins>${newWord ?? ""}</ins>`;
      }

      if (i === newWords.length - 1 && opts.markLastWord) {
        wordHTML = `<mark class="highlight">${wordHTML}</mark>`;
      }

      diff.push(wordHTML);

      // Add a line break after this word if it ended a line in the original text
      if (lineBreakMap.has(i)) {
        diff.push("<br>");
      }

      i++;
    }

    return diff.join(" ");
  }
}
