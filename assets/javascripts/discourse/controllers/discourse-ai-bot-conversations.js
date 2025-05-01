import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";

export default class DiscourseAiBotConversations extends Controller {
  @service aiBotConversationsHiddenSubmit;
  @service currentUser;
  @service mediaOptimizationWorker;
  @service site;
  @service siteSettings;

  @tracked uploads = [];
  // Don't track this directly - we'll get it from uppyUpload

  textarea = null;
  uppyUpload = null;
  fileInputEl = null;

  _handlePaste = (event) => {
    if (document.activeElement !== this.textarea) {
      return;
    }

    const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });

    if (!canUpload || canPasteHtml || types.includes("text/plain")) {
      return;
    }

    if (event && event.clipboardData && event.clipboardData.files) {
      this.uppyUpload.addFiles([...event.clipboardData.files], {
        pasted: true,
      });
    }
  };

  init() {
    super.init(...arguments);

    this.uploads = [];

    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: "ai-bot-file-uploader",
      type: "ai-bot-conversation",
      useMultipartUploadsIfAvailable: true,

      uppyReady: () => {
        if (this.siteSettings.composer_media_optimization_image_enabled) {
          this.uppyUpload.uppyWrapper.useUploadPlugin(UppyMediaOptimization, {
            optimizeFn: (data, opts) =>
              this.mediaOptimizationWorker.optimizeImage(data, opts),
            runParallel: !this.site.isMobileDevice,
          });
        }

        this.uppyUpload.uppyWrapper.onPreProcessProgress((file) => {
          const inProgressUpload = this.inProgressUploads?.find(
            (upl) => upl.id === file.id
          );
          if (inProgressUpload && !inProgressUpload.processing) {
            inProgressUpload.processing = true;
          }
        });

        this.uppyUpload.uppyWrapper.onPreProcessComplete((file) => {
          const inProgressUpload = this.inProgressUploads?.find(
            (upl) => upl.id === file.id
          );
          if (inProgressUpload) {
            inProgressUpload.processing = false;
          }
        });

        // Setup paste listener for the textarea
        this.textarea?.addEventListener("paste", this._handlePaste);
      },

      uploadDone: (upload) => {
        this.uploads.pushObject(upload);
      },

      // Fix: Don't try to set inProgressUploads directly
      onProgressUploadsChanged: () => {
        // This is just for UI triggers - we're already tracking inProgressUploads
        this.notifyPropertyChange("inProgressUploads");
      },
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.textarea?.removeEventListener("paste", this._handlePaste);
    this.uppyUpload?.teardown();
  }

  get loading() {
    return this.aiBotConversationsHiddenSubmit?.loading;
  }

  get inProgressUploads() {
    return this.uppyUpload?.inProgressUploads || [];
  }

  get showUploadsContainer() {
    return this.uploads?.length > 0 || this.inProgressUploads?.length > 0;
  }

  @action
  setPersonaId(id) {
    this.aiBotConversationsHiddenSubmit.personaId = id;
  }

  @action
  setTargetRecipient(username) {
    this.aiBotConversationsHiddenSubmit.targetUsername = username;
  }

  @action
  updateInputValue(value) {
    this._autoExpandTextarea();
    this.aiBotConversationsHiddenSubmit.inputValue =
      value.target?.value || value;
  }

  @action
  handleKeyDown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      this.prepareAndSubmitToBot();
    }
  }

  @action
  setTextArea(element) {
    this.textarea = element;
  }

  @action
  registerFileInput(element) {
    if (element) {
      this.fileInputEl = element;
      if (this.uppyUpload) {
        this.uppyUpload.setup(element);
      }
    }
  }

  @action
  openFileUpload() {
    if (this.fileInputEl) {
      this.fileInputEl.click();
    }
  }

  @action
  removeUpload(upload) {
    this.uploads.removeObject(upload);
  }

  @action
  cancelUpload(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
  }

  @action
  prepareAndSubmitToBot() {
    // Pass uploads to the service before submitting
    this.aiBotConversationsHiddenSubmit.uploads = this.uploads;
    this.aiBotConversationsHiddenSubmit.submitToBot();
  }

  _autoExpandTextarea() {
    this.textarea.style.height = "auto";
    this.textarea.style.height = this.textarea.scrollHeight + "px";

    // Get the max-height value from CSS (30vh)
    const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10);

    // Only enable scrolling if content exceeds max-height
    if (this.textarea.scrollHeight > maxHeight) {
      this.textarea.style.overflowY = "auto";
    } else {
      this.textarea.style.overflowY = "hidden";
    }
  }
}
