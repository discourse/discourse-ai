import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import I18n from "discourse-i18n";

export default apiInitializer("1.25.0", (api) => {
  const buttonAttrs = {
    label: I18n.t("discourse_ai.ai_helper.image_caption.button_label"),
    icon: "discourse-sparkles",
    class: "generate-caption",
  };
  const settings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (
    !settings.ai_helper_enabled_features.includes("image_caption") ||
    !currentUser?.can_use_assistant
  ) {
    return;
  }

  api.addSaveableUserOptionField("auto_image_caption");

  api.addComposerImageWrapperButton(
    buttonAttrs.label,
    buttonAttrs.class,
    buttonAttrs.icon,
    (event) => {
      const imageCaptionPopup = api.container.lookup(
        "service:imageCaptionPopup"
      );

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

        imageCaptionPopup.toggleLoadingState(true);

        const site = api.container.lookup("site:main");
        if (!site.mobileView) {
          imageCaptionPopup.showPopup = !imageCaptionPopup.showPopup;
        }

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
              imageCaptionPopup.updateCaption();
            }
          })
          .catch(popupAjaxError)
          .finally(() => {
            imageCaptionPopup.toggleLoadingState(false);
          });
      }
    }
  );
});
