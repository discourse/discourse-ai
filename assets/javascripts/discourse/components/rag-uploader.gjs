import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import icon from "discourse-common/helpers/d-icon";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";
import RagUploadProgress from "./rag-upload-progress";

export default class RagUploader extends Component {
  @service appEvents;
  @tracked term = null;
  @tracked filteredUploads = null;
  @tracked ragIndexingStatuses = null;
  @tracked ragUploads = null;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "discourse-ai-rag-uploader",
    maxFiles: 20,
    type: "discourse_ai_rag_upload",
    uploadUrl:
      "/admin/plugins/discourse-ai/rag-document-fragments/files/upload",
    preventDirectS3Uploads: true,
    uploadDone: (uploadedFile) => {
      const newUpload = uploadedFile.upload;
      newUpload.status = "uploaded";
      newUpload.statusText = I18n.t("discourse_ai.rag.uploads.uploaded");
      this.ragUploads.pushObject(newUpload);
      this.debouncedSearch();
    },
  });

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.uppyUpload.inProgressUploads?.length > 0) {
      this.uppyUpload.cancelAllUploads();
    }

    this.ragUploads = this.target?.rag_uploads || [];
    this.filteredUploads = this.ragUploads;

    const targetName = this.target?.constructor?.name;

    if (this.ragUploads?.length && this.target?.id) {
      ajax(
        `/admin/plugins/discourse-ai/rag-document-fragments/files/status.json?target_type=${targetName}&target_id=${this.target.id}`
      ).then((statuses) => {
        this.set("ragIndexingStatuses", statuses);
      });
    }

    this.appEvents.on(
      `upload-mixin:${this.uppyUpload.config.id}:all-uploads-complete`,
      this,
      "_updateTargetWithUploads"
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      `upload-mixin:${this.uppyUpload.config}:all-uploads-complete`,
      this,
      "_updateTargetWithUploads"
    );
  }

  _updateTargetWithUploads() {
    this.updateUploads(this.ragUploads);
  }

  @action
  submitFiles() {
    this.uppyUpload.openPicker();
  }

  @action
  cancelUploading(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
  }

  @action
  search() {
    if (this.term) {
      this.filteredUploads = this.ragUploads.filter((u) => {
        return (
          u.original_filename.toUpperCase().indexOf(this.term.toUpperCase()) >
          -1
        );
      });
    } else {
      this.filteredUploads = this.ragUploads;
    }
  }

  @action
  debouncedSearch() {
    discourseDebounce(this, this.search, 100);
  }

  @action
  removeUpload(upload) {
    this.ragUploads.removeObject(upload);
    this.onRemove(upload);

    this.debouncedSearch();
  }

  <template>
    <div class="rag-uploader">
      <h3>{{I18n.t "discourse_ai.rag.uploads.title"}}</h3>
      <p>{{I18n.t "discourse_ai.rag.uploads.description"}}</p>

      {{#if this.ragUploads}}
        <div class="rag-uploader__search-input-container">
          <div class="rag-uploader__search-input">
            {{icon "search" class="rag-uploader__search-input__search-icon"}}
            <Input
              class="rag-uploader__search-input__input"
              placeholder={{I18n.t "discourse_ai.rag.uploads.filter"}}
              @value={{this.term}}
              {{on "keyup" this.debouncedSearch}}
            />
          </div>
        </div>
      {{/if}}

      <table class="rag-uploader__uploads-list">
        <tbody>
          {{#each this.filteredUploads as |upload|}}
            <tr>
              <td>
                <span class="rag-uploader__rag-file-icon">{{icon "file"}}</span>
                {{upload.original_filename}}
              </td>
              <RagUploadProgress
                @upload={{upload}}
                @ragIndexingStatuses={{this.ragIndexingStatuses}}
              />
              <td class="rag-uploader__remove-file">
                <DButton
                  @icon="times"
                  @title="discourse_ai.rag.uploads.remove"
                  @action={{fn this.removeUpload upload}}
                  @class="btn-flat"
                />
              </td>
            </tr>
          {{/each}}
          {{#each this.uppyUpload.inProgressUploads as |upload|}}
            <tr>
              <td><span class="rag-uploader__rag-file-icon">{{icon
                    "file"
                  }}</span>
                {{upload.original_filename}}</td>
              <td class="rag-uploader__upload-status">
                <div class="spinner small"></div>
                <span>{{I18n.t "discourse_ai.rag.uploads.uploading"}}
                  {{upload.uploadProgress}}%</span>
              </td>
              <td class="rag-uploader__remove-file">
                <DButton
                  @icon="times"
                  @title="discourse_ai.rag.uploads.remove"
                  @action={{fn this.cancelUploading upload}}
                  @class="btn-flat"
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>

      <input
        {{didInsert this.uppyUpload.setup}}
        class="hidden-upload-field"
        disabled={{this.uploading}}
        type="file"
        multiple="multiple"
        accept=".txt,.md"
      />
      <DButton
        @label="discourse_ai.rag.uploads.button"
        @icon="plus"
        @title="discourse_ai.rag.uploads.button"
        @action={{this.submitFiles}}
        class="btn-default"
      />
    </div>
  </template>
}
