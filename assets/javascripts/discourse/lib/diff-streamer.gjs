import { tracked } from "@glimmer/tracking";
import { later } from "@ember/runloop";
import loadJSDiff from "discourse/lib/load-js-diff";
import { IMAGE_MARKDOWN_REGEX } from "discourse/lib/uploads";

const DEFAULT_CHAR_TYPING_DELAY = 30;

export default class DiffStreamer {
  @tracked isStreaming = false;
  @tracked words = [];
  @tracked lastResultText = "";
  @tracked diff = "";
  @tracked suggestion = "";
  @tracked isDone = false;

  typingTimer = null;
  currentWordIndex = 0;
  currentCharIndex = 0;
  jsDiff = null;

  constructor(selectedText, typingDelay) {
    this.selectedText = selectedText;
    this.typingDelay = typingDelay || DEFAULT_CHAR_TYPING_DELAY;
    this.loadJSDiff();
  }

  async loadJSDiff() {
    this.jsDiff = await loadJSDiff();
  }

  async updateResult(result, newTextKey) {
    if (!this.jsDiff) {
      await this.loadJSDiff();
    }

    const newText = result[newTextKey];
    this.isDone = !!result?.done;

    if (newText.length < this.lastResultText.length) {
      // reset if text got shorter (e.g., reset or new input)
      this.words = [];
      this.suggestion = "";
      this.currentWordIndex = 0;
      this.currentCharIndex = 0;
    }

    const diffText = newText.slice(this.lastResultText.length);
    if (!diffText.trim()) {
      this.lastResultText = newText;
      return;
    }

    const newWords = this.#tokenizeMarkdownAware(diffText);

    if (newWords.length > 0) {
      this.isStreaming = true;
      this.words.push(...newWords);
      if (!this.typingTimer) {
        this.#streamNextChar();
      }
    }

    this.lastResultText = newText;
  }

  #tokenizeMarkdownAware(text) {
    const tokens = [];
    let lastIndex = 0;

    let match;
    while ((match = IMAGE_MARKDOWN_REGEX.exec(text)) !== null) {
      const matchStart = match.index;

      if (lastIndex < matchStart) {
        const preceding = text.slice(lastIndex, matchStart);
        tokens.push(...(preceding.match(/\S+\s*|\s+/g) || []));
      }

      tokens.push(match[0]);

      lastIndex = IMAGE_MARKDOWN_REGEX.lastIndex;
    }

    if (lastIndex < text.length) {
      const trailing = text.slice(lastIndex);
      tokens.push(...(trailing.match(/\S+\s*|\s+/g) || []));
    }

    return tokens;
  }

  reset() {
    this.diff = "";
    this.suggestion = "";
    this.lastResultText = "";
    this.words = [];
    this.currentWordIndex = 0;
    this.currentCharIndex = 0;
    this.isStreaming = false;
    if (this.typingTimer) {
      clearTimeout(this.typingTimer);
      this.typingTimer = null;
    }
  }

  async #streamNextChar() {
    if (this.currentWordIndex < this.words.length) {
      const currentToken = this.words[this.currentWordIndex];

      const isMarkdownToken =
        currentToken.startsWith("![") || currentToken.startsWith("[");

      if (isMarkdownToken) {
        this.suggestion += currentToken;

        this.currentWordIndex++;
        this.currentCharIndex = 0;

        const originalDiff = this.jsDiff.diffWordsWithSpace(
          this.selectedText,
          this.suggestion
        );

        this.diff = this.#formatDiffWithTags(originalDiff);

        if (this.currentWordIndex === 1) {
          this.diff = this.diff.replace(/^\s+/, "");
        }

        this.typingTimer = later(this, this.#streamNextChar, this.typingDelay);
      } else {
        const nextChar = currentToken.charAt(this.currentCharIndex);
        this.suggestion += nextChar;
        this.currentCharIndex++;

        if (this.currentCharIndex >= currentToken.length) {
          this.currentWordIndex++;
          this.currentCharIndex = 0;

          const originalDiff = this.jsDiff.diffWordsWithSpace(
            this.selectedText,
            this.suggestion
          );

          this.diff = this.#formatDiffWithTags(originalDiff);

          if (this.currentWordIndex === 1) {
            this.diff = this.diff.replace(/^\s+/, "");
          }
        }

        this.typingTimer = later(this, this.#streamNextChar, this.typingDelay);
      }
    } else {
      if (!this.suggestion || !this.selectedText || !this.jsDiff) {
        return;
      }

      const originalDiff = this.jsDiff.diffWordsWithSpace(
        this.selectedText,
        this.suggestion
      );

      this.typingTimer = null;
      this.diff = this.#formatDiffWithTags(originalDiff, false);
      this.isStreaming = false;
    }
  }

  #wrapChunk(text, type) {
    if (type === "added") {
      return `<ins>${text}</ins>`;
    }
    if (type === "removed") {
      if (/^\s+$/.test(text)) {
        return "";
      }
      return `<del>${text}</del>`;
    }
    return `<span>${text}</span>`;
  }

  #formatDiffWithTags(diffArray, highlightLastWord = true) {
    const wordsWithType = [];
    diffArray.forEach((part) => {
      const tokens = part.value.match(/\S+|\s+/g) || [];
      tokens.forEach((token) => {
        wordsWithType.push({
          text: token,
          type: part.added ? "added" : part.removed ? "removed" : "unchanged",
        });
      });
    });

    let lastWordIndex = -1;
    if (highlightLastWord) {
      for (let i = wordsWithType.length - 1; i >= 0; i--) {
        if (
          wordsWithType[i].type !== "removed" &&
          /\S/.test(wordsWithType[i].text)
        ) {
          lastWordIndex = i;
          break;
        }
      }
    }

    const output = [];

    for (let i = 0; i <= lastWordIndex; i++) {
      const { text, type } = wordsWithType[i];

      if (/^\s+$/.test(text)) {
        output.push(text);
        continue;
      }

      let content = this.#wrapChunk(text, type);

      if (highlightLastWord && i === lastWordIndex) {
        content = `<mark class="highlight">${content}</mark>`;
      }

      output.push(content);
    }

    if (lastWordIndex < wordsWithType.length - 1) {
      let i = lastWordIndex + 1;
      while (i < wordsWithType.length) {
        let chunkType = wordsWithType[i].type;
        let chunkText = "";

        while (
          i < wordsWithType.length &&
          wordsWithType[i].type === chunkType
        ) {
          chunkText += wordsWithType[i].text;
          i++;
        }

        output.push(this.#wrapChunk(chunkText, chunkType));
      }
    }

    return output.join("");
  }
}
