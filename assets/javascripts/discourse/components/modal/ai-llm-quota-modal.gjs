import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import DurationSelector from "../ai-quota-duration-selector";

export default class AiLlmQuotaModal extends Component {
  @service site;

  @tracked groupIds = null;
  @tracked maxTokens = null;
  @tracked maxUsages = null;
  @tracked duration = 86400; // Default 1 day

  get canSave() {
    return (
      this.groupIds?.length > 0 &&
      (this.maxTokens || this.maxUsages) &&
      this.duration
    );
  }

  @action
  updateGroups(groups) {
    this.groupIds = groups;
  }

  @action
  updateDuration(value) {
    this.duration = value;
  }

  @action
  updateMaxTokens(event) {
    this.maxTokens = event.target.value;
  }

  @action
  updateMaxUsages(event) {
    this.maxUsages = event.target.value;
  }

  @action
  save() {
    const quota = {
      group_id: this.groupIds[0],
      group_name: this.site.groups.findBy("id", this.groupIds[0]).name,
      llm_model_id: this.args.model.id,
      max_tokens: this.maxTokens,
      max_usages: this.maxUsages,
      duration_seconds: this.duration,
    };

    this.args.model.llm.llm_quotas.pushObject(quota);
    this.args.closeModal();
    if (this.args.model.onSave) {
      this.args.model.onSave();
    }
  }

  get availableGroups() {
    const existingQuotaGroupIds =
      this.args.model.llm.llm_quotas.map((q) => q.group_id) || [];

    return this.site.groups.filter(
      (group) => !existingQuotaGroupIds.includes(group.id) && group.id !== 0
    );
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.llms.quotas.add_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "discourse_ai.llms.quotas.group"}}</label>
          <GroupChooser
            @value={{this.groupIds}}
            @content={{this.availableGroups}}
            @onChange={{this.updateGroups}}
            @options={{hash maximum=1}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.llms.quotas.max_tokens"}}</label>
          <input
            type="number"
            value={{this.maxTokens}}
            class="input-large"
            min="1"
            {{on "input" this.updateMaxTokens}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.llms.quotas.max_usages"}}</label>
          <input
            type="number"
            value={{this.maxUsages}}
            class="input-large"
            min="1"
            {{on "input" this.updateMaxUsages}}
          />
        </div>

        <div class="control-group">
          <label>{{i18n "discourse_ai.llms.quotas.duration"}}</label>
          <DurationSelector
            @value={{this.duration}}
            @onChange={{this.updateDuration}}
          />
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="discourse_ai.llms.quotas.add"
          @disabled={{not this.canSave}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
