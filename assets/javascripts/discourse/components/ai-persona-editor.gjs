import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { later } from "@ember/runloop";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import DTooltip from "float-kit/components/d-tooltip";
import AiCommandSelector from "./ai-command-selector";
import AiPersonaCommandOptions from "./ai-persona-command-options";

export default class PersonaEditor extends Component {
  @service router;
  @service store;
  @service dialog;
  @service toasts;

  @tracked allGroups = [];
  @tracked isSaving = false;
  @tracked editingModel = null;
  @tracked showDelete = false;

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.showDelete = !this.args.model.isNew && !this.args.model.system;
  }

  @action
  async updateAllGroups() {
    this.allGroups = await Group.findAll();
  }

  @action
  async save() {
    const isNew = this.args.model.isNew;
    this.isSaving = true;

    const backupModel = this.args.model.workingCopy();

    this.args.model.setProperties(this.editingModel);
    try {
      await this.args.model.save();
      this.#sortPersonas();
      if (isNew) {
        this.args.personas.addObject(this.args.model);
        this.router.transitionTo(
          "adminPlugins.discourse-ai.ai-personas.show",
          this.args.model
        );
      } else {
        this.toasts.success({
          data: { message: I18n.t("discourse_ai.ai_persona.saved") },
          duration: 2000,
        });
      }
    } catch (e) {
      this.args.model.setProperties(backupModel);
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  get showTemperature() {
    return this.editingModel?.temperature || !this.editingModel?.system;
  }

  get showTopP() {
    return this.editingModel?.top_p || !this.editingModel?.system;
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.ai_persona.confirm_delete"),
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          this.args.personas.removeObject(this.args.model);
          this.router.transitionTo(
            "adminPlugins.discourse-ai.ai-personas.index"
          );
        });
      },
    });
  }

  @action
  updateAllowedGroups(ids) {
    this.editingModel.set("allowed_group_ids", ids);
  }

  @action
  async toggleEnabled() {
    this.args.model.set("enabled", !this.args.model.enabled);
    this.editingModel.set("enabled", this.args.model.enabled);
    if (!this.args.model.isNew) {
      try {
        await this.args.model.update({ enabled: this.args.model.enabled });
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  @action
  async togglePriority() {
    this.args.model.set("priority", !this.args.model.priority);
    this.editingModel.set("priority", this.args.model.priority);
    if (!this.args.model.isNew) {
      try {
        await this.args.model.update({ priority: this.args.model.priority });

        this.#sortPersonas();
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  #sortPersonas() {
    const sorted = this.args.personas.toArray().sort((a, b) => {
      if (a.priority && !b.priority) {
        return -1;
      } else if (!a.priority && b.priority) {
        return 1;
      } else {
        return a.name.localeCompare(b.name);
      }
    });
    this.args.personas.clear();
    this.args.personas.setObjects(sorted);
  }

  <template>
    <form
      class="form-horizontal ai-persona-editor"
      {{didUpdate this.updateModel @model.id}}
      {{didInsert this.updateModel @model.id}}
      {{didInsert this.updateAllGroups @model.id}}
    >
      <div class="control-group">
        <DToggleSwitch
          class="ai-persona-editor__enabled"
          @state={{@model.enabled}}
          @label="discourse_ai.ai_persona.enabled"
          {{on "click" this.toggleEnabled}}
        />
      </div>
      <div class="control-group ai-persona-editor__priority">
        <DToggleSwitch
          class="ai-persona-editor__priority"
          @state={{@model.priority}}
          @label="discourse_ai.ai_persona.priority"
          {{on "click" this.togglePriority}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.ai_persona.priority_help"}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.name"}}</label>
        <Input
          class="ai-persona-editor__name"
          @type="text"
          @value={{this.editingModel.name}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.description"}}</label>
        <Textarea
          class="ai-persona-editor__description"
          @value={{this.editingModel.description}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.commands"}}</label>
        <AiCommandSelector
          class="ai-persona-editor__commands"
          @value={{this.editingModel.commands}}
          @disabled={{this.editingModel.system}}
          @commands={{@personas.resultSetMeta.commands}}
        />
      </div>
      {{#unless this.editingModel.system}}
        <AiPersonaCommandOptions
          @persona={{this.editingModel}}
          @commands={{this.editingModel.commands}}
          @allCommands={{@personas.resultSetMeta.commands}}
        />
      {{/unless}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.allowed_groups"}}</label>
        <GroupChooser
          @value={{this.editingModel.allowed_group_ids}}
          @content={{this.allGroups}}
          @onChange={{this.updateAllowedGroups}}
        />
      </div>
      <div class="control-group">
        <label for="ai-persona-editor__system_prompt">{{I18n.t
            "discourse_ai.ai_persona.system_prompt"
          }}</label>
        <Textarea
          class="ai-persona-editor__system_prompt"
          @value={{this.editingModel.system_prompt}}
          disabled={{this.editingModel.system}}
        />
      </div>
      {{#if this.showTemperature}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.ai_persona.temperature"}}</label>
          <Input
            @type="number"
            class="ai-persona-editor__temperature"
            @value={{this.editingModel.temperature}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.ai_persona.temperature_help"}}
          />
        </div>
      {{/if}}
      {{#if this.showTopP}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.ai_persona.top_p"}}</label>
          <Input
            @type="number"
            class="ai-persona-editor__top_p"
            @value={{this.editingModel.top_p}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.ai_persona.top_p_help"}}
          />
        </div>
      {{/if}}
      <div class="control-group ai-persona-editor__action_panel">
        <DButton
          class="btn-primary ai-persona-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >{{I18n.t "discourse_ai.ai_persona.save"}}</DButton>
        {{#if this.showDelete}}
          <DButton
            @action={{this.delete}}
            class="btn-danger ai-persona-editor__delete"
          >
            {{I18n.t "discourse_ai.ai_persona.delete"}}
          </DButton>
        {{/if}}
      </div>
    </form>
  </template>
}
