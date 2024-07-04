import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import eq from "truth-helpers/helpers/eq";
import AiPostHelperMenu from "../../components/ai-post-helper-menu";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AIHelperOptionsMenu extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }

  @service site;
  @service menu;

  @tracked menuState = this.MENU_STATES.triggers;
  @tracked showMainButtons = true;
  @tracked showAiButtons = true;
  @tracked originalPostHTML = null;
  @tracked postHighlighted = false;
  @tracked currentMenu = this.menu.getByIdentifier(
    "post-text-selection-toolbar"
  );

  MENU_STATES = {
    triggers: "TRIGGERS",
    options: "OPTIONS",
  };

  highlightSelectedText() {
    const postId = this.args.outletArgs.data.quoteState.postId;
    const postElement = document.querySelector(
      `article[data-post-id='${postId}'] .cooked`
    );

    if (!postElement) {
      return;
    }

    this.originalPostHTML = postElement.innerHTML;
    this.selectedText = this.args.outletArgs.data.quoteState.buffer;

    const selection = window.getSelection();
    if (!selection.rangeCount) {
      return;
    }

    const range = selection.getRangeAt(0);

    // Split start/end text nodes at their range boundary
    if (
      range.startContainer.nodeType === Node.TEXT_NODE &&
      range.startOffset > 0
    ) {
      const newStartNode = range.startContainer.splitText(range.startOffset);
      range.setStart(newStartNode, 0);
    }
    if (
      range.endContainer.nodeType === Node.TEXT_NODE &&
      range.endOffset < range.endContainer.length
    ) {
      range.endContainer.splitText(range.endOffset);
    }

    // Create a Walker to traverse text nodes within range
    const walker = document.createTreeWalker(
      range.commonAncestorContainer,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: (node) =>
          range.intersectsNode(node)
            ? NodeFilter.FILTER_ACCEPT
            : NodeFilter.FILTER_REJECT,
      }
    );

    const textNodes = [];

    if (walker.currentNode?.nodeType === Node.TEXT_NODE) {
      textNodes.push(walker.currentNode);
    } else {
      while (walker.nextNode()) {
        textNodes.push(walker.currentNode);
      }
    }

    for (let textNode of textNodes) {
      const highlight = document.createElement("span");
      highlight.classList.add("ai-helper-highlighted-selection");

      // Replace textNode with highlighted clone
      const clone = textNode.cloneNode(true);
      highlight.appendChild(clone);

      textNode.parentNode.replaceChild(highlight, textNode);
    }

    selection.removeAllRanges();
    this.postHighlighted = true;
  }

  removeHighlightedText() {
    if (!this.postHighlighted) {
      return;
    }

    const postId = this.args.outletArgs.data.quoteState.postId;
    const postElement = document.querySelector(
      `article[data-post-id='${postId}'] .cooked`
    );

    if (!postElement) {
      return;
    }

    postElement.innerHTML = this.originalPostHTML;
    this.postHighlighted = false;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.removeHighlightedText();
  }

  @action
  async showAiHelperOptions() {
    this.highlightSelectedText();
    if (this.site.mobileView) {
      this.currentMenu.close();

      await this.menu.show(virtualElementFromTextRange(), {
        identifier: "ai-post-helper-menu",
        component: AiPostHelperMenu,
        inline: true,
        placement: this.shouldRenderUnder ? "bottom-start" : "top-start",
        fallbackPlacements: this.shouldRenderUnder
          ? ["bottom-end", "top-start"]
          : ["bottom-start"],
        trapTab: false,
        closeOnScroll: false,
        modalForMobile: true,
        data: this.menuData,
      });
    }

    this.showMainButtons = false;
    this.menuState = this.MENU_STATES.options;
  }

  get menuData() {
    // Streamline of data model to be passed to the component when
    // instantiated as a DMenu or a simple component in the template
    return {
      ...this.args.outletArgs.data,
      quoteState: {
        buffer: this.args.outletArgs.data.quoteState.buffer,
        opts: this.args.outletArgs.data.quoteState.opts,
        postId: this.args.outletArgs.data.quoteState.postId,
      },
      post: this.args.outletArgs.post,
      selectedText: this.selectedText,
    };
  }

  <template>
    {{#if this.showMainButtons}}
      {{yield}}
    {{/if}}

    {{#if this.showAiButtons}}
      <div class="ai-post-helper">
        {{#if (eq this.menuState this.MENU_STATES.triggers)}}
          <DButton
            @icon="discourse-sparkles"
            @title="discourse_ai.ai_helper.post_options_menu.title"
            @label="discourse_ai.ai_helper.post_options_menu.trigger"
            @action={{this.showAiHelperOptions}}
            class="btn-flat ai-post-helper__trigger"
          />

        {{else if (eq this.menuState this.MENU_STATES.options)}}
          <AiPostHelperMenu @data={{this.menuData}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
