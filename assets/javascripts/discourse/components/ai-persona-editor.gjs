import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import GroupSelector from "discourse/components/group-selector";
import Group from "discourse/models/group";
import I18n from "discourse-i18n";
import AiCommandSelector from "discourse/plugins/discourse-ai/discourse/components/ai-command-selector";

export default class PersonaEditor extends Component {

  constructor() {
    super(...arguments);
    this.model = this.args.model;
  }

  groupFinder(term) {
    return Group.findAll({ term });
  }

  @action
  save() {
    this.model.save().then(() => {
      if (this.args.onSave) {
        this.args.onSave();
      }
    });
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
      <GroupSelector @groupFinder={{this.groupFinder}} @groupNames={{this.model.allowed_groups_names}} />
    </div>
    <div class="control-group">
      <label for="persona-editor__system_prompt">{{I18n.t "discourse_ai.ai-persona.system_prompt"}}</label>
      <Textarea class="persona-editor__system_prompt" @value={{this.model.system_prompt}} />
    </div>
    <div class="control-group">
      <DButton @action={{this.save}} >{{I18n.t "discourse_ai.ai-persona.save"}}</DButton>
    </div>
    </form>
  </template>
}
