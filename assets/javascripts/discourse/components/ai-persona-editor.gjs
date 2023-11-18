import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import later from "discourse-common/lib/later";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import AiCommandSelector from "./ai-command-selector";

export default class PersonaEditor extends Component {
  @service router;
  @service store;
  @service dialog;

  @tracked allGroups = [];
  @tracked isSaving = false;
  @tracked justSaved = false;
  @tracked model = null;

  constructor() {
    super(...arguments);

    Group.findAll().then((groups) => {
      this.allGroups = groups;
    });
  }

  @action
  updateModel() {
    this.model = this.args.model.createProperties();
  }

  @action
  save() {
    const isNew = this.args.model.isNew;
    let error = false;
    this.isSaving = true;

    let start = Date.now();

    this.args.model.setProperties(this.model);
    this.args.model
      .save()
      .catch((e) => {
        popupAjaxError(e);
        error = true;
      })
      .finally(() => {
        if (!error) {
          if (isNew) {
            this.args.personas.addObject(this.args.model);
            this.router.transitionTo(
              "adminPlugins.discourse-ai.ai-personas.show",
              this.args.model
            );
          } else {
            later(() => {
              this.isSaving = false;
              this.justSaved = true;
              later(() => {
                this.justSaved = false;
              }, 2000);
            }, Math.max(0, 500 - (Date.now() - start)));
          }
        }
      });
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.ai-persona.confirm_delete"),
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
    this.model.set("allowed_group_ids", ids);
  }

  @action
  toggleEnabled() {
    this.args.model.set("enabled", !this.args.model.enabled);
    this.args.model.update({ enabled: this.args.model.enabled });
  }

  <template>
    <form
      class="form-horizontal ai-persona-editor"
      {{didUpdate this.updateModel @model.id}}
      {{didInsert this.updateModel @model.id}}
    >
      <div class="control-group">
        <DToggleSwitch
          class="ai-persona-editor__enabled"
          @state={{@model.enabled}}
          @label="discourse_ai.ai-persona.enabled"
          {{on "click" this.toggleEnabled}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai-persona.name"}}</label>
        <Input
          class="ai-persona-editor__name"
          @type="text"
          @value={{this.model.name}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai-persona.description"}}</label>
        <Textarea
          class="ai-persona-editor__description"
          @value={{this.model.description}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai-persona.commands"}}</label>
        <AiCommandSelector
          class="ai-persona-editor__commands"
          @value={{this.model.commands}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai-persona.allowed_groups"}}</label>
        <GroupChooser
          @value={{this.model.allowed_group_ids}}
          @content={{this.allGroups}}
          @onChange={{this.updateAllowedGroups}}
        />
      </div>
      <div class="control-group">
        <label for="ai-persona-editor__system_prompt">{{I18n.t
            "discourse_ai.ai-persona.system_prompt"
          }}</label>
        <Textarea
          class="ai-persona-editor__system_prompt"
          @value={{this.model.system_prompt}}
          disabled={{this.model.system}}
        />
      </div>
      <div class="control-group ai-persona-editor__action_panel">
        <DButton
          class="btn-primary ai-persona-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >{{I18n.t "discourse_ai.ai-persona.save"}}</DButton>
        {{#if this.justSaved}}
          <span class="ai-persona-editor__saved">
            {{I18n.t "discourse_ai.ai-persona.saved"}}
          </span>
        {{/if}}
        {{#unless @model.system}}
          <DButton
            @action={{this.delete}}
            class="btn-danger ai-persona-editor__delete"
          >
            {{I18n.t "discourse_ai.ai-persona.delete"}}
          </DButton>
        {{/unless}}
      </div>
    </form>
  </template>
}
