import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import I18n from "discourse-i18n";
import { IMAGE_MARKDOWN_REGEX } from "../discourse/lib/utilities";

export default apiInitializer("1.25.0", (api) => {
  const buttonAttrs = {
    label: I18n.t("discourse_ai.ai_helper.image_caption.button_label"),
    icon: "discourse-sparkles",
    class: "generate-caption",
  };
  const imageCaptionPopup = api.container.lookup("service:imageCaptionPopup");
  const settings = api.container.lookup("service:site-settings");
  const appEvents = api.container.lookup("service:app-events");
  const site = api.container.lookup("site:main");

  if (!settings.ai_helper_enabled_features.includes("image_caption")) {
    return;
  }
  api.addComposerImageWrapperButton(
    buttonAttrs.label,
    buttonAttrs.class,
    buttonAttrs.icon,
    (event) => {
      imageCaptionPopup.popupTrigger = event.target;

      if (
        imageCaptionPopup.popupTrigger.classList.contains("generate-caption")
      ) {
        const buttonWrapper = event.target.closest(".button-wrapper");
        const imageIndex = parseInt(
          buttonWrapper.getAttribute("data-image-index"),
          10
        );
        const imageSrc = event.target
          .closest(".image-wrapper")
          .querySelector("img")
          .getAttribute("src");

        imageCaptionPopup.loading = true;

        if (!site.mobileView) {
          imageCaptionPopup.showPopup = !imageCaptionPopup.showPopup;
        }

        imageCaptionPopup.popupTrigger.classList.add("disabled");

        imageCaptionPopup._request = ajax(
          `/discourse-ai/ai-helper/caption_image`,
          {
            method: "POST",
            data: {
              image_url: imageSrc,
            },
          }
        );

        imageCaptionPopup._request
          .then(({ caption }) => {
            imageCaptionPopup.imageSrc = imageSrc;
            imageCaptionPopup.imageIndex = imageIndex;
            imageCaptionPopup.newCaption = caption;

            if (site.mobileView) {
              // Auto-saves caption on mobile view
              const composer = api.container.lookup("service:composer");

              const matchingPlaceholder =
                composer.model.reply.match(IMAGE_MARKDOWN_REGEX);
              const match = matchingPlaceholder[imageIndex];
              const replacement = match.replace(
                IMAGE_MARKDOWN_REGEX,
                `![${imageCaptionPopup.newCaption}|$2$3$4]($5)`
              );
              appEvents.trigger("composer:replace-text", match, replacement);
            }
          })
          .catch(popupAjaxError)
          .finally(() => {
            imageCaptionPopup.loading = false;
            imageCaptionPopup.popupTrigger.classList.remove("disabled");
          });
      }
    }
  );
});
