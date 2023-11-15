import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Group from "discourse/models/group";
import later from "discourse-common/lib/later";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import AiCommandSelector from "./ai-command-selector";


export default class PersonaEditor extends Component {
  @service store;
  @service dialog;

  @tracked allGroups = [];
  @tracked isSaving = false;
  @tracked justSaved = false;

  constructor() {
    super(...arguments);
    this.model = this.args.model || this.store.createRecord('ai-persona');

    Group.findAll().then((groups) => {
      this.allGroups = groups;
    });
  }



  @action
  save() {
    this.isSaving = true;

    let start = Date.now();

    this.model.save().then(() => {
      if (this.args.onSave) {
        this.args.onSave();
      }
    }).finally(() => {
        later(() => {
          this.isSaving = false;
          this.justSaved = true;
          later(() => {
            this.justSaved = false;
          }, 2000);
        }, Math.max(0, 500 - (Date.now() - start)));
    });
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.ai-persona.confirm_delete"),
      didConfirm: () => {
        return this.model.destroyRecord().then(() => {
          if (this.args.onDelete) {
            this.args.onDelete();
          }
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
    this.model.set("enabled", !this.model.enabled);
  }

  <template>
  <form class="form-horizontal persona-editor">
    <div class="control-group">
      <label for="name">{{I18n.t "discourse_ai.ai-persona.name"}}</label>
      <Input @type="text" @value={{this.model.name}} />
    </div>
    <div class="control-group">
      <label for="persona-editor__description">{{I18n.t "discourse_ai.ai-persona.description"}}</label>
      <Textarea class="persona-editor__description" @value={{this.model.description}} />
    </div>
    <div class="control-group">
      <label for="persona-editor__commands">{{I18n.t "discourse_ai.ai-persona.commands"}}</label>
      <AiCommandSelector class="persona-editor__commands" @value={{this.model.commands}} />
    </div>
    <div class="control-group">
      <label for="allowed_groups">{{I18n.t "discourse_ai.ai-persona.allowed_groups"}}</label>
      <GroupChooser
        @value={{this.model.allowed_group_ids}}
        @content={{this.allGroups}}
        @onChange={{this.updateAllowedGroups}} />
    </div>
    <div class="control-group">
      <label for="persona-editor__system_prompt">{{I18n.t "discourse_ai.ai-persona.system_prompt"}}</label>
      <Textarea class="persona-editor__system_prompt" @value={{this.model.system_prompt}} />
    </div>
    <div class="control-group">
      <DToggleSwitch
        class="persona-editor__enabled"
        @state={{this.model.enabled}}
        @label="discourse_ai.ai-persona.enabled"
        {{on "click" this.toggleEnabled}}
        />
    </div>
    <div class="control-group persona-editor__action_panel">
      <DButton
        class="btn-primary persona-editor__save"
        @action={{this.save}}
        @disabled={{this.isSaving}}
      >{{I18n.t "discourse_ai.ai-persona.save"}}</DButton>
      {{#if this.justSaved}}
        <span class="persona-editor__saved">
          {{I18n.t "discourse_ai.ai-persona.saved"}}
        </span>
      {{/if}}
      <DButton @icon="far-trash-alt" @action={{this.delete}} class="btn-danger persona-editor__delete" />
    </div>
    </form>
  </template>
}
