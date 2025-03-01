import { schedule } from "@ember/runloop";

export default class SimpleTextareaInteractor {
  // lifted from "discourse/plugins/chat/discourse/lib/textarea-interactor"
  // because the chat plugin isn't active on this site
  constructor(textarea) {
    this.textarea = textarea;
    this.init();
    this.refreshHeightBound = this.refreshHeight.bind(this);
    this.textarea.addEventListener("input", this.refreshHeightBound);
  }

  init() {
    schedule("afterRender", () => {
      this.refreshHeight();
    });
  }

  teardown() {
    this.textarea.removeEventListener("input", this.refreshHeightBound);
  }

  refreshHeight() {
    schedule("afterRender", () => {
      this.textarea.style.height = "auto";
      this.textarea.style.height = `${this.textarea.scrollHeight + 2}px`;
    });
  }
}
