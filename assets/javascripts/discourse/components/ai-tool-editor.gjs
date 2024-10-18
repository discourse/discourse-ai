import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import AceEditor from "discourse/components/ace-editor";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/components/d-tooltip";
import InputTip from "discourse/components/input-tip";
import withEventValue from "discourse/helpers/with-event-value";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse-common/lib/debounce";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import AiTool from "../admin/models/ai-tool";
import AiToolParameterEditor from "./ai-tool-parameter-editor";
import AiToolTestModal from "./modal/ai-tool-test-modal";
import RagOptions from "./rag-options";
import RagUploader from "./rag-uploader";

const ACE_EDITOR_MODE = "javascript";
const ACE_EDITOR_THEME = "chrome";

export default class AiToolEditor extends Component {
  @service router;
  @service dialog;
  @service modal;
  @service toasts;
  @service store;
  @service siteSettings;

  @tracked jobName = null;
  @tracked isSaving = false;
  @tracked editingModel = null;
  @tracked showDelete = false;
  @tracked selectedPreset = null;

  @tracked disableSave = null;
  @tracked nameValidation = null;

  get presets() {
    return this.args.presets.map((preset) => {
      return {
        name: preset.preset_name,
        id: preset.preset_id,
      };
    });
  }

  get showPresets() {
    return !this.selectedPreset && this.args.model.isNew;
  }

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.showDelete = !this.args.model.isNew;
    this.jobName = this.editingModel.name;
  }

  @action
  configurePreset() {
    this.selectedPreset = this.args.presets.findBy("preset_id", this.presetId);
    this.editingModel = this.store
      .createRecord("ai-tool", this.selectedPreset)
      .workingCopy();
    this.showDelete = false;
  }

  @action
  updateUploads(uploads) {
    this.editingModel.rag_uploads = uploads;
  }

  @action
  removeUpload(upload) {
    this.editingModel.rag_uploads.removeObject(upload);
    if (!this.args.model.isNew) {
      this.save();
    }
  }

  @action
  validateAndUpdateName(value) {
    // Skip validation if name hasn't changed
    if (value === this.jobName) {
      this._failedInputValidation("");
      this.disableSave = false;
      return;
    }

    this.editingModel.name = value;

    if (value === undefined) {
      return this._failedInputValidation();
    }

    if (isEmpty(value)) {
      return this._failedInputValidation(
        I18n.t("discourse_ai.tools.new.name.blank")
      );
    }

    this._checkToolNameDebounced();

    return this._failedInputValidation(
      I18n.t("discourse_ai.tools.new.name.checking")
    );
  }

  _checkToolNameDebounced() {
    discourseDebounce(this, this._checkToolName, 500);
  }

  _checkToolName() {
    if (isEmpty(this.editingModel.name)) {
      return;
    }

    AiTool.checkName(this.editingModel.name)
      .then((response) => {
        if (response.available) {
          this.disableSave = false;
          this.nameValidation = {
            ok: true,
            reason: I18n.t("discourse_ai.tools.new.name.available"),
          };
        } else {
          this.disableSave = true;
          let reason = response.errors.join(" ");
          this.validationName = this._failedInputValidation(reason);
        }
      })
      .catch(popupAjaxError);
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      const data = this.editingModel.getProperties(
        "name",
        "description",
        "parameters",
        "script",
        "summary",
        "rag_uploads",
        "rag_chunk_tokens",
        "rag_chunk_overlap_tokens"
      );

      await this.args.model.save(data);

      this.toasts.success({
        data: { message: I18n.t("discourse_ai.tools.saved") },
        duration: 2000,
      });
      if (!this.args.tools.any((tool) => tool.id === this.args.model.id)) {
        this.args.tools.pushObject(this.args.model);
      }

      this.router.transitionTo(
        "adminPlugins.show.discourse-ai-tools.show",
        this.args.model
      );
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.tools.confirm_delete"),
      didConfirm: async () => {
        await this.args.model.destroyRecord();

        this.args.tools.removeObject(this.args.model);
        this.router.transitionTo("adminPlugins.show.discourse-ai-tools.index");
      },
    });
  }

  @action
  openTestModal() {
    this.modal.show(AiToolTestModal, {
      model: {
        tool: this.editingModel,
      },
    });
  }

  get disableSaveButton() {
    return this.disableSave || this.isSaving;
  }

  _failedInputValidation(reason) {
    this.disableSave = true;
    const options = { failed: true };
    if (reason) {
      options.reason = reason;
    }
    this.nameValidation = options;
    return options;
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-tools"
      @label="discourse_ai.tools.back"
    />

    <form
      {{didInsert this.updateModel @model.id}}
      {{didUpdate this.updateModel @model.id}}
      class="form-horizontal ai-tool-editor"
    >
      {{#if this.showPresets}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.presets"}}</label>
          <ComboBox
            @value={{this.presetId}}
            @content={{this.presets}}
            class="ai-tool-editor__presets"
          />
        </div>

        <div class="control-group ai-llm-editor__action_panel">
          <DButton
            @action={{this.configurePreset}}
            @label="discourse_ai.tools.next.title"
            class="ai-tool-editor__next"
          />
        </div>
      {{else}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.name"}}</label>
          <input
            {{on "input" (withEventValue this.validateAndUpdateName)}}
            value={{this.editingModel.name}}
            type="text"
            class="ai-tool-editor__name"
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.tools.name_help"}}
          />
          <InputTip @validation={{this.nameValidation}} />
        </div>

        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.description"}}</label>
          <textarea
            {{on
              "input"
              (withEventValue (fn (mut this.editingModel.description)))
            }}
            placeholder={{I18n.t "discourse_ai.tools.description_help"}}
            class="ai-tool-editor__description input-xxlarge"
          >{{this.editingModel.description}}</textarea>
        </div>

        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.summary"}}</label>
          <input
            {{on "input" (withEventValue (fn (mut this.editingModel.summary)))}}
            value={{this.editingModel.summary}}
            type="text"
            class="ai-tool-editor__summary input-xxlarge"
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.tools.summary_help"}}
          />
        </div>

        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.parameters"}}</label>
          <AiToolParameterEditor @parameters={{this.editingModel.parameters}} />
        </div>

        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.script"}}</label>
          <AceEditor
            @content={{this.editingModel.script}}
            @onChange={{fn (mut this.editingModel.script)}}
            @mode={{ACE_EDITOR_MODE}}
            @theme={{ACE_EDITOR_THEME}}
            @editorId="ai-tool-script-editor"
          />
        </div>

        {{#if this.siteSettings.ai_embeddings_enabled}}
          <div class="control-group">
            <RagUploader
              @target={{this.editingModel}}
              @updateUploads={{this.updateUploads}}
              @onRemove={{this.removeUpload}}
            />
          </div>
          <RagOptions @model={{this.editingModel}} />
        {{/if}}

        <div class="control-group ai-tool-editor__action_panel">
          <DButton
            @action={{this.openTestModal}}
            @label="discourse_ai.tools.test"
            class="ai-tool-editor__test-button"
          />

          <DButton
            @action={{this.save}}
            @label="discourse_ai.tools.save"
            @disabled={{this.disableSaveButton}}
            class="btn-primary ai-tool-editor__save"
          />

          {{#if this.showDelete}}
            <DButton
              @action={{this.delete}}
              @label="discourse_ai.tools.delete"
              class="btn-danger ai-tool-editor__delete"
            />
          {{/if}}
        </div>
      {{/if}}
    </form>
  </template>
}
