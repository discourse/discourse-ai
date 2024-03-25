import { tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import icon from "discourse-common/helpers/d-icon";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";

export default class PersonaRagUploader extends Component.extend(
  UppyUploadMixin
) {
  @service appEvents;

  @tracked term = null;
  @tracked filteredUploads = null;
  id = "discourse-ai-persona-rag-uploader";
  maxFiles = 20;
  uploadUrl = "/admin/plugins/discourse-ai/ai-personas/files/upload";
  preventDirectS3Uploads = true;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.inProgressUploads?.length > 0) {
      this._uppyInstance?.cancelAll();
    }

    this.filteredUploads = this.ragUploads || [];
  }

  uploadDone(uploadedFile) {
    this.onAdd(uploadedFile.upload);
    this.debouncedSearch();
  }

  @action
  submitFiles() {
    this.fileInputEl.click();
  }

  @action
  cancelUploading(upload) {
    this.appEvents.trigger(`upload-mixin:${this.id}:cancel-upload`, {
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

  <template>
    <div class="persona-rag-uploader">
      <h3>{{I18n.t "discourse_ai.ai_persona.uploads.title"}}</h3>
      <p>{{I18n.t "discourse_ai.ai_persona.uploads.description"}}</p>

      <div class="persona-rag-uploader__search-input-container">
        <div class="persona-rag-uploader__search-input">
          {{icon
            "search"
            class="persona-rag-uploader__search-input__search-icon"
          }}
          <Input
            class="persona-rag-uploader__search-input__input"
            placeholder={{I18n.t "discourse_ai.ai_persona.uploads.filter"}}
            @value={{this.term}}
            {{on "keyup" this.debouncedSearch}}
          />
        </div>
      </div>

      <table class="persona-rag-uploader__uploads-list">
        <tbody>
          {{#each this.filteredUploads as |upload|}}
            <tr>
              <td>
                <span class="persona-rag-uploader__rag-file-icon">{{icon
                    "file"
                  }}</span>
                {{upload.original_filename}}</td>
              <td class="persona-rag-uploader__upload-status">{{icon "check"}}
                {{I18n.t "discourse_ai.ai_persona.uploads.complete"}}</td>
              <td class="persona-rag-uploader__remove-file">
                <DButton
                  @icon="times"
                  @title="discourse_ai.ai_persona.uploads.remove"
                  @action={{fn @onRemove upload}}
                  @class="btn-flat"
                />
              </td>
            </tr>
          {{/each}}
          {{#each this.inProgressUploads as |upload|}}
            <tr>
              <td><span class="persona-rag-uploader__rag-file-icon">{{icon
                    "file"
                  }}</span>
                {{upload.original_filename}}</td>
              <td class="persona-rag-uploader__upload-status">
                <div class="spinner small"></div>
                <span>{{I18n.t "discourse_ai.ai_persona.uploads.uploading"}}
                  {{upload.uploadProgress}}%</span>
              </td>
              <td class="persona-rag-uploader__remove-file">
                <DButton
                  @icon="times"
                  @title="discourse_ai.ai_persona.uploads.remove"
                  @action={{fn this.cancelUploading upload}}
                  @class="btn-flat"
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>

      <input
        class="hidden-upload-field"
        disabled={{this.uploading}}
        type="file"
        multiple="multiple"
        accept=".txt"
      />
      <DButton
        @label="discourse_ai.ai_persona.uploads.button"
        @icon="plus"
        @title="discourse_ai.ai_persona.uploads.button"
        @action={{this.submitFiles}}
        class="btn-default"
      />
    </div>
  </template>
}
