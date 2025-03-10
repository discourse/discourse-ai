import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AiToolEditorForm from "./ai-tool-editor-form";
import AiToolTestModal from "./modal/ai-tool-test-modal";

export default class AiToolEditor extends Component {
  @service router;
  @service dialog;
  @service modal;
  @service toasts;
  @service store;
  @service siteSettings;

  @tracked isSaving = false;
  @tracked editingModel = null;

  constructor() {
    super(...arguments);
    this.updateModel();
  }

  get selectedPreset() {
    if (!this.args.selectedPreset) {
      return this.args.presets.findBy("preset_id", "empty_tool");
    }

    return this.args.presets.findBy("preset_id", this.args.selectedPreset);
  }

  updateModel() {
    if (this.args.model.isNew) {
      this.editingModel = this.store
        .createRecord("ai-tool", this.selectedPreset)
        .workingCopy();
    } else {
      this.editingModel = this.args.model.workingCopy();
    }
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      const data = this.editingModel.getProperties(
        "name",
        "tool_name",
        "description",
        "parameters",
        "script",
        "summary",
        "rag_uploads",
        "rag_chunk_tokens",
        "rag_chunk_overlap_tokens",
        "rag_llm_model_id"
      );

      await this.args.model.save(data);

      this.toasts.success({
        data: { message: i18n("discourse_ai.tools.saved") },
        duration: 2000,
      });
      if (!this.args.tools.any((tool) => tool.id === this.args.model.id)) {
        this.args.tools.pushObject(this.args.model);
      }

      this.router.transitionTo(
        "adminPlugins.show.discourse-ai-tools.edit",
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
      message: i18n("discourse_ai.tools.confirm_delete"),
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

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-tools"
      @label="discourse_ai.tools.back"
    />

    <AiToolEditorForm
      @editingModel={{this.editingModel}}
      @isNew={{@model.isNew}}
      @selectedPreset={{this.selectedPreset}}
    />

    <hr />
    <hr />
    <hr />

    <form class="form-horizontal ai-tool-editor">

      <div class="control-group ai-tool-editor__action_panel">
        {{#unless @model.isNew}}
          <DButton
            @action={{this.openTestModal}}
            @label="discourse_ai.tools.test"
            class="ai-tool-editor__test-button"
          />
        {{/unless}}
      </div>
    </form>
  </template>
}
