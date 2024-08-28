import { later } from "@ember/runloop";
import loadMorphlex from "discourse/lib/load-morphlex";
import { cook } from "discourse/lib/text";

const PROGRESS_INTERVAL = 40;
const GIVE_UP_INTERVAL = 60000;
export const MIN_LETTERS_PER_INTERVAL = 6;
const MAX_FLUSH_TIME = 800;

let progressTimer = null;

function lastNonEmptyChild(element) {
  let lastChild = element.lastChild;
  while (
    lastChild &&
    lastChild.nodeType === Node.TEXT_NODE &&
    !/\S/.test(lastChild.textContent)
  ) {
    lastChild = lastChild.previousSibling;
  }
  return lastChild;
}

export function addProgressDot(element) {
  let lastBlock = element;

  while (true) {
    let lastChild = lastNonEmptyChild(lastBlock);
    if (!lastChild) {
      break;
    }

    if (lastChild.nodeType === Node.ELEMENT_NODE) {
      lastBlock = lastChild;
    } else {
      break;
    }
  }

  const dotElement = document.createElement("span");
  dotElement.classList.add("progress-dot");
  lastBlock.appendChild(dotElement);
}

// this is the interface we need to implement
// for a streaming updater
class StreamUpdater {
  set streaming(value) {
    throw "not implemented";
  }

  async setCooked() {
    throw "not implemented";
  }

  async setRaw() {
    throw "not implemented";
  }

  get element() {
    throw "not implemented";
  }

  get raw() {
    throw "not implemented";
  }
}

class PostUpdater extends StreamUpdater {
  morphingOptions = {
    beforeAttributeUpdated: (element, attributeName) => {
      return !(element.tagName === "DETAILS" && attributeName === "open");
    },
  };

  constructor(postStream, postId) {
    super();
    this.postStream = postStream;
    this.postId = postId;
    this.post = postStream.findLoadedPost(postId);

    if (this.post) {
      this.postElement = document.querySelector(
        `#post_${this.post.post_number}`
      );
    }
  }

  get element() {
    return this.postElement;
  }

  set streaming(value) {
    if (this.postElement) {
      if (value) {
        this.postElement.classList.add("streaming");
      } else {
        this.postElement.classList.remove("streaming");
      }
    }
  }

  async setRaw(value, done) {
    this.post.set("raw", value);
    const cooked = await cook(value);

    // resets animation
    this.element.classList.remove("streaming");
    void this.element.offsetWidth;
    this.element.classList.add("streaming");

    const cookedElement = document.createElement("div");
    cookedElement.innerHTML = cooked;

    if (!done) {
      addProgressDot(cookedElement);
    }

    await this.setCooked(cookedElement.innerHTML);
  }

  async setCooked(value) {
    this.post.set("cooked", value);

    (await loadMorphlex()).morphInner(
      this.postElement.querySelector(".cooked"),
      `<div>${value}</div>`,
      this.morphingOptions
    );
  }

  get raw() {
    return this.post.get("raw") || "";
  }
}

export class SummaryUpdater extends StreamUpdater {
  constructor(topicSummary) {
    super();
    this.topicSummary = topicSummary;

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
        this.element.classList.add("streaming");
      } else {
        this.element.classList.remove("streaming");
      }
    }
  }

  async setRaw(value, done) {
    console.log("setRaw called", value, done);
    this.topicSummary.raw = value;
    const cooked = await cook(value);

    // resets animation
    this.element.classList.remove("streaming");
    void this.element.offsetWidth;
    this.element.classList.add("streaming");

    const cookedElement = document.createElement("div");
    cookedElement.innerHTML = cooked;

    if (!done) {
      addProgressDot(cookedElement);
    }

    await this.setCooked(cookedElement.innerHTML);
  }

  async setCooked(value) {
    const cookedContainer = this.element.querySelector(".generated-summary");
    cookedContainer.innerHTML = value;
  }

  get raw() {
    return this.topicSummary.raw || "";
  }
}

export async function applyProgress(status, updater) {
  status.startTime = status.startTime || Date.now();

  if (Date.now() - status.startTime > GIVE_UP_INTERVAL) {
    updater.streaming = false;
    return true;
  }

  if (!updater.element) {
    // wait till later
    return false;
  }

  const oldRaw = updater.raw;
  // TODO: figure out `status.raw` === `oldRaw` shouldn't be ===
  if (status.raw === oldRaw && !status.done) {
    const hasProgressDot = updater.element.querySelector(".progress-dot");
    if (hasProgressDot) {
      return false;
    }
  }

  console.log("status.raw", status.raw);
  if (status.raw !== undefined) {
    let newRaw = status.raw;
    console.log("rawdiff", newRaw === oldRaw, newRaw.length, oldRaw.length);

    console.log("!status.done", !status.done);
    if (!status.done) {
      // rush update if we have a </details> tag (function call)
      if (oldRaw.length === 0 && newRaw.indexOf("</details>") !== -1) {
        console.log("details called");
        newRaw = status.raw;
      } else {
        const diff = newRaw.length - oldRaw.length;
        console.log("diff", diff);

        // progress interval is 40ms
        // by default we add 6 letters per interval
        // but ... we want to be done in MAX_FLUSH_TIME
        let letters = Math.floor(diff / (MAX_FLUSH_TIME / PROGRESS_INTERVAL));
        if (letters < MIN_LETTERS_PER_INTERVAL) {
          letters = MIN_LETTERS_PER_INTERVAL;
        }

        newRaw = status.raw.substring(0, oldRaw.length + letters);
      }
    }

    await updater.setRaw(newRaw, status.done);
  }

  if (status.done) {
    if (status.cooked) {
      await updater.setCooked(status.cooked);
    }
    updater.streaming = false;
  }

  return status.done;
}

async function handleProgress(postStream) {
  const status = postStream.aiStreamingStatus;

  let keepPolling = false;

  const promises = Object.keys(status).map(async (postId) => {
    let postStatus = status[postId];

    const postUpdater = new PostUpdater(postStream, postStatus.post_id);
    const done = await applyProgress(postStatus, postUpdater);

    if (done) {
      delete status[postId];
    } else {
      keepPolling = true;
    }
  });

  await Promise.all(promises);
  return keepPolling;
}

async function ensureSummaryProgress(topicSummary) {
  const summaryUpdater = new SummaryUpdater(topicSummary);
  if (!progressTimer) {
    progressTimer = later(async () => {
      const keepPolling = await applyProgress(topicSummary, summaryUpdater);

      console.log("ensureSummaryProgress keep polling", keepPolling);
      progressTimer = null;

      if (!topicSummary.done) {
        console.log("keepPolling called");
        await applyProgress(topicSummary, summaryUpdater);
      }
    }, PROGRESS_INTERVAL);
  }
}

function ensureProgress(postStream) {
  if (!progressTimer) {
    progressTimer = later(async () => {
      const keepPolling = await handleProgress(postStream);

      progressTimer = null;

      if (keepPolling) {
        ensureProgress(postStream);
      }
    }, PROGRESS_INTERVAL);
  }
}

export function streamSummaryText(topicSummary) {
  if (topicSummary.done) {
    console.log("stream summary text already done");
    return;
  }

  ensureSummaryProgress(topicSummary);
}

export default function streamText(postStream, data) {
  if (data.noop) {
    return;
  }

  let status = (postStream.aiStreamingStatus =
    postStream.aiStreamingStatus || {});
  status[data.post_id] = data;
  ensureProgress(postStream);
}
