import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import { getUploadMarkdown, isImage } from "discourse/lib/uploads";
import I18n from "discourse-i18n";
import { IMAGE_MARKDOWN_REGEX } from "../discourse/lib/utilities";

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

  function needsImprovedCaption(caption) {
    return caption.length < 20 || caption.split(" ").length === 1;
  }

  // Automatically caption uploaded images
  api.addComposerUploadMarkdownResolver(async (upload) => {
    const autoCaptionEnabled = currentUser.get(
      "user_option.auto_image_caption"
    );

    if (
      !autoCaptionEnabled ||
      !isImage(upload.url) ||
      !needsImprovedCaption(upload.original_filename)
    ) {
      return getUploadMarkdown(upload);
    }

    try {
      const { caption } = await ajax(`/discourse-ai/ai-helper/caption_image`, {
        method: "POST",
        data: {
          image_url: upload.url,
        },
      });

      return `![${caption}|${upload.thumbnail_width}x${upload.thumbnail_height}](${upload.short_url})`;
    } catch (error) {
      popupAjaxError(error);
    }
  });

  // Conditionally show dialog to auto image caption
  api.composerBeforeSave(() => {
    return new Promise((resolve, reject) => {
      const dialog = api.container.lookup("service:dialog");
      const composer = api.container.lookup("service:composer");
      const localePrefix =
        "discourse_ai.ai_helper.image_caption.automatic_caption_dialog";
      const autoCaptionEnabled = currentUser.get(
        "user_option.auto_image_caption"
      );

      const imageUploads = composer.model.reply.match(IMAGE_MARKDOWN_REGEX);
      const hasImageUploads = imageUploads?.length > 0;
      const imagesToCaption = imageUploads.filter((image) => {
        const caption = image
          .substring(image.indexOf("[") + 1, image.indexOf("]"))
          .split("|")[0];
        // TODO add check for if image is not small
        return needsImprovedCaption(caption);
      });
      const needsBetterCaptions = imagesToCaption?.length > 0;

      // TODO: add logic to resolve() if user has:
      // - [] seen this dialog before
      if (autoCaptionEnabled || !hasImageUploads || !needsBetterCaptions) {
        resolve();
      }

      dialog.confirm({
        message: I18n.t(`${localePrefix}.prompt`),
        confirmButtonLabel: `${localePrefix}.confirm`,
        cancelButtonLabel: `${localePrefix}.cancel`,
        class: "ai-image-caption-prompt-dialog",

        didConfirm: async () => {
          try {
            currentUser.set("user_option.auto_image_caption", true);
            await currentUser.save(["auto_image_caption"]);

            // TODO: generate caption for all images in composer before resolving
            resolve();
          } catch (error) {
            // Reject the promise if an error occurs
            // Show an error saying unable to generate captions
            reject(error);
          }
        },
        didCancel: () => {
          // Don't enable auto captions and continue with the save
          // TODO: add logic to stop showing this dialog
          resolve();
        },
      });
    });
  });
});
