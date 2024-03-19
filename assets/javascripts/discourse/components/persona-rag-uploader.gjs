import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class PersonaRagUploader extends Component.extend(
  UppyUploadMixin
) {
  @service appEvents;

  id = "discourse-ai-persona-rag-uploader";
  maxFiles = 20;
  uploadUrl = "/admin/plugins/discourse-ai/ai-personas/files/upload";
  preventDirectS3Uploads = true;

  didReceiveAttrs() {
    super.didReceiveAttrs();
    super.didReceiveAttrs(...arguments);
    if (this.inProgressUploads?.length > 0) {
      this._uppyInstance?.cancelAll();
    }
  }

  uploadDone(uploadedFile) {
    this.onAdd(uploadedFile.upload);
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

  <template>
    <label>{{I18n.t "discourse_ai.ai_persona.uploads.title"}}</label>
    <p>{{I18n.t "discourse_ai.ai_persona.uploads.description"}}</p>

    <table class="rag-uploads">
      <tbody>
        {{#each @ragUploads as |upload|}}
          <tr>
            <td><span class="rag-file-icon">{{icon "file"}}</span>
              {{upload.original_filename}}</td>
            <td class="upload-status {{upload.status}}">{{icon "check"}}
              {{upload.statusText}}</td>
            <td>
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
            <td><span class="rag-file-icon">{{icon "file"}}</span>
              {{upload.original_filename}}</td>
            <td class="upload-status">
              <div class="spinner small"></div>
              <span>{{I18n.t "discourse_ai.ai_persona.uploads.uploading"}}
                {{upload.uploadProgress}}%</span>
            </td>
            <td>
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
  </template>
}
