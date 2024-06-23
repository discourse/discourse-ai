import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import AiToolParameterEditor from "./ai-tool-parameter-editor";

export default class AiToolEditor extends Component {
  @service router;
  @service store;
  @service dialog;

  @tracked isSaving = false;
  @tracked editingModel = null;
  @tracked showDelete = false;

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.showDelete = !this.args.model.isNew;
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
          "script"
        )
      );
      this.args.tools.pushObject(this.args.model);
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
      message: I18n.t("discourse_ai.ai_tool.confirm_delete"),
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
  updateParameters(parameters) {
    this.editingModel.parameters = parameters;
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-tools"
      @label="discourse_ai.ai_tool.back"
    />
    <form
      class="form-horizontal ai-tool-editor"
      {{on "submit" this.save}}
      {{didUpdate this.updateModel @model.id}}
      {{didInsert this.updateModel @model.id}}
    >
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.tools.name"}}</label>
        <Input
          @type="text"
          @value={{this.editingModel.name}}
          class="ai-tool-editor__name"
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.tools.description"}}</label>
        <Textarea
          @value={{this.editingModel.description}}
          class="ai-tool-editor__description"
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.tools.parameters"}}</label>
        <AiToolParameterEditor
          @parameters={{this.editingModel.parameters}}
          @onChange={{this.updateParameters}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.tools.script"}}</label>
        <Textarea
          @value={{this.editingModel.script}}
          class="ai-tool-editor__script"
        />
      </div>
      <div class="control-group ai-tool-editor__action_panel">
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
            {{I18n.t "discourse_ai.ai_tool.delete"}}
          </DButton>
        {{/if}}
      </div>
    </form>
  </template>
}
