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
  const imageCaptionPopup = api.container.lookup("service:imageCaptionPopup");

  api.addComposerImageWrapperButton(
    buttonAttrs.label,
    buttonAttrs.class,
    buttonAttrs.icon,
    (event) => {
      if (event.target.classList.contains("generate-caption")) {
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
        imageCaptionPopup.showPopup = !imageCaptionPopup.showPopup;

        ajax(`/discourse-ai/ai-helper/caption_image`, {
          method: "POST",
          data: {
            image_url: imageSrc,
          },
        })
          .then(({ caption }) => {
            event.target.classList.add("disabled");
            imageCaptionPopup.imageSrc = imageSrc;
            imageCaptionPopup.imageIndex = imageIndex;
            imageCaptionPopup.newCaption = caption;
          })
          .catch(popupAjaxError)
          .finally(() => {
            imageCaptionPopup.loading = false;
            event.target.classList.remove("disabled");
          });
      }
    }
  );
});
