import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import Group from "discourse/models/group";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import AiCommandSelector from "discourse/plugins/discourse-ai/discourse/components/ai-command-selector";

export default class PersonaEditor extends Component {
  @service store;
  @service dialog;

  constructor() {
    super(...arguments);
    this.model = this.args.model || this.store.createRecord('ai-persona');
  }

  @action
  save() {
    this.model.save().then(() => {
      if (this.args.onSave) {
        this.args.onSave();
      }
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

  async searchGroups(term) {
    if (!term) {
      return Promise.resolve([]);
    }

    return await Group.findAll({term});
  }

  @action
  updateAllowedGroups(ids) {
    this.model.set("allowed_group_ids", ids);
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
          @search={{this.searchGroups}}
          @onChange={{this.updateAllowedGroups}}
          @labelProperty="name"/>
    </div>
    <div class="control-group">
      <label for="persona-editor__system_prompt">{{I18n.t "discourse_ai.ai-persona.system_prompt"}}</label>
      <Textarea class="persona-editor__system_prompt" @value={{this.model.system_prompt}} />
    </div>
    <div class="control-group">
      <DButton class="btn-primary" @action={{this.save}} >{{I18n.t "discourse_ai.ai-persona.save"}}</DButton>
      <DButton @icon="far-trash-alt" @action={{this.delete}} class="btn-danger" />
    </div>
    </form>
  </template>
}
