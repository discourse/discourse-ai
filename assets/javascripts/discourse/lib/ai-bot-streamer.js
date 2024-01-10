import { later } from "@ember/runloop";
import loadScript from "discourse/lib/load-script";
import { cook } from "discourse/lib/text";

const PROGRESS_INTERVAL = 40;
const GIVE_UP_INTERVAL = 10000;
const LETTERS_PER_INTERVAL = 6;

let progressTimer = null;

async function applyProgress(postStatus, postStream) {
  postStatus.startTime = postStatus.startTime || Date.now();
  let post = postStream.findLoadedPost(postStatus.post_id);

  const postElement = document.querySelector(`#post_${postStatus.post_number}`);

  if (Date.now() - postStatus.startTime > GIVE_UP_INTERVAL) {
    if (postElement) {
      postElement.classList.remove("streaming");
    }
    return true;
  }

  if (!post) {
    // wait till later
    return false;
  }

  const oldRaw = post.get("raw") || "";
  if (postStatus.raw === oldRaw && !postStatus.done) {
    // nothing to do for now
    return false;
  }

  if (postStatus.raw) {
    const newRaw = postStatus.raw.substring(
      0,
      oldRaw.length + LETTERS_PER_INTERVAL
    );
    const cooked = await cook(newRaw);

    post.set("raw", newRaw);
    post.set("cooked", cooked);

    // resets animation
    postElement.classList.remove("streaming");
    void postElement.offsetWidth;
    postElement.classList.add("streaming");

    const cookedElement = document.createElement("div");
    cookedElement.innerHTML = cooked;

    let element = document.querySelector(
      `#post_${postStatus.post_number} .cooked`
    );

    await loadScript("/javascripts/diffhtml.min.js");
    window.diff.innerHTML(element, cookedElement.innerHTML);
  }

  if (postStatus.done) {
    if (postElement) {
      postElement.classList.remove("streaming");
    }
  }

  return postStatus.done;
}

async function handleProgress(postStream) {
  let status = postStream.aiStreamingStatus;

  let keepPolling = false;

  let promises = Object.keys(status).map(async (postId) => {
    let postStatus = status[postId];

    const done = await applyProgress(postStatus, postStream);

    if (done) {
      delete status[postId];
    } else {
      keepPolling = true;
    }
  });

  await Promise.all(promises);
  return keepPolling;
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

export default function streamText(postStream, data) {
  let status = (postStream.aiStreamingStatus =
    postStream.aiStreamingStatus || {});
  status[data.post_id] = data;
  ensureProgress(postStream);
}
