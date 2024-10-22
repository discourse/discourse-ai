import { cook } from "discourse/lib/text";
import StreamUpdater from "./stream-updater";

export default class SummaryUpdater extends StreamUpdater {
  constructor(topicSummary, componentContext) {
    super();
    this.topicSummary = topicSummary;
    this.componentContext = componentContext;

    if (this.topicSummary) {
      this.summaryBox = document.querySelector("article.ai-summary-box");
    }
  }

  get element() {
    return this.summaryBox;
  }

  set streaming(value) {
    if (this.element) {
      if (value) {
        this.componentContext.isStreaming = true;
      } else {
        this.componentContext.isStreaming = false;
      }
    }
  }

  async setRaw(value, done) {
    this.componentContext.oldRaw = value;
    const cooked = await cook(value);

    await this.setCooked(cooked);

    if (done) {
      this.componentContext.finalSummary = cooked;
    }
  }

  async setCooked(value) {
    this.componentContext.text = value;
  }

  get raw() {
    return this.componentContext.oldRaw || "";
  }
}
