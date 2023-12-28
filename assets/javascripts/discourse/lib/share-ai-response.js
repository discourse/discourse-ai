// mostly copied from core
import { SVG_NAMESPACE } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export function recentlyCopiedShare(postId) {
  return document.querySelector(
    `article[data-post-id='${postId}'] .post-action-menu__share .post-action-menu__share-checkmark`
  );
}

export function showShareAlert(postId) {
  const postSelector = `article[data-post-id='${postId}']`;
  const shareBtn = document.querySelector(
    `${postSelector} .post-action-menu__share`
  );
  createAlert(
    I18n.t("discourse_ai.ai_bot.conversation_shared"),
    postId,
    shareBtn
  );
  createCheckmark(shareBtn, postId);
  styleShareBtn(shareBtn);
}

function createAlert(message, postId, shareBtn) {
  if (!shareBtn) {
    return;
  }

  let alertDiv = document.createElement("div");
  alertDiv.className = "share-copied-alert -success";
  alertDiv.textContent = message;

  shareBtn.appendChild(alertDiv);

  setTimeout(() => alertDiv.classList.add("slide-out"), 1000);
  setTimeout(() => removeElement(alertDiv), 2500);
}

function createCheckmark(btn, postId) {
  const checkmark = makeCheckmarkSvg(postId);
  btn.appendChild(checkmark.content);

  setTimeout(() => checkmark.classList.remove("is-visible"), 3000);
  setTimeout(
    () =>
      removeElement(document.querySelector(`#copy_post_svg_postId_${postId}`)),
    3500
  );
}

function styleShareBtn(shareBtn) {
  shareBtn.classList.add("is-copied");
  setTimeout(() => shareBtn.classList.remove("is-copied"), 3200);
}

function makeCheckmarkSvg(postId) {
  const svgElement = document.createElement("template");
  svgElement.innerHTML = `
      <svg class="post-action-menu__share-checkmark is-visible" id="copy_post_svg_postId_${postId}" xmlns="${SVG_NAMESPACE}" viewBox="0 0 52 52">
        <path class="checkmark__check" fill="none" d="M13 26 l10 10 20 -20"/>
      </svg>
    `;
  return svgElement;
}

function removeElement(element) {
  element?.parentNode?.removeChild(element);
}
