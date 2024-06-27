import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DTooltip from "discourse/components/d-tooltip";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import AceEditor from "admin/components/ace-editor";
import ComboBox from "select-kit/components/combo-box";
import AiToolParameterEditor from "./ai-tool-parameter-editor";
import AiToolTestModal from "./modal/ai-tool-test-modal";

export default class AiToolEditor extends Component {
  @service router;
  @service store;
  @service dialog;
  @service modal;
  @service toasts;

  @tracked isSaving = false;
  @tracked editingModel = null;
  @tracked showDelete = false;

  @tracked selectedPreset = null;

  aceEditorMode = "javascript";
  aceEditorTheme = "chrome";

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.showDelete = !this.args.model.isNew;
  }

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
  configurePreset() {
    this.selectedPreset = this.args.presets.findBy("preset_id", this.presetId);
    this.editingModel = this.args.model.workingCopy();
    this.editingModel.setProperties(this.selectedPreset);
    this.showDelete = false;
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.args.model.save(
        this.editingModel.getProperties(
          "name",
          "description",
          "parameters",
          "script",
          "summary"
        )
      );

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
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          this.args.tools.removeObject(this.args.model);
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-tools.index"
          );
        });
      },
    });
  }

  @action
  updateScript(script) {
    this.editingModel.script = script;
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
      @label="discourse_ai.ai_tool.back"
    />

    <form
      class="form-horizontal ai-tool-editor"
      {{didUpdate this.updateModel @model.id}}
      {{didInsert this.updateModel @model.id}}
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
            class="ai-tool-editor__next"
            @action={{this.configurePreset}}
          >
            {{I18n.t "discourse_ai.tools.next.title"}}
          </DButton>
        </div>
      {{else}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.name"}}</label>
          <Input
            @type="text"
            @value={{this.editingModel.name}}
            class="ai-tool-editor__name"
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.tools.name_help"}}
          />
        </div>
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.description"}}</label>
          <Textarea
            @value={{this.editingModel.description}}
            class="ai-tool-editor__description"
            placeholder={{I18n.t "discourse_ai.tools.description_help"}}
          />
        </div>
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.tools.summary"}}</label>
          <Input
            @type="text"
            @value={{this.editingModel.summary}}
            class="ai-tool-editor__summary"
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
            @mode={{this.aceEditorMode}}
            @theme={{this.aceEditorTheme}}
            @onChange={{this.updateScript}}
            @editorId="ai-tool-script-editor"
          />
        </div>
        <div class="control-group ai-tool-editor__action_panel">
          <DButton
            @action={{this.openTestModal}}
            class="btn-default ai-tool-editor__test-button"
          >{{I18n.t "discourse_ai.tools.test"}}</DButton>
          <DButton
            class="btn-primary ai-tool-editor__save"
            @action={{this.save}}
            @disabled={{this.isSaving}}
          >{{I18n.t "discourse_ai.tools.save"}}</DButton>
          {{#if this.showDelete}}
            <DButton
              @action={{this.delete}}
              class="btn-danger ai-tool-editor__delete"
            >
              {{I18n.t "discourse_ai.tools.delete"}}
            </DButton>
          {{/if}}
        </div>
      {{/if}}
    </form>
  </template>
}
