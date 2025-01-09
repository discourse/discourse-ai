import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import DurationSelector from "./ai-quota-duration-selector";

export default class AiLlmQuotaEditor extends Component {
  @service store;
  @service dialog;
  @service site;

  @tracked newQuotaGroupIds = null;
  @tracked newQuotaTokens = null;
  @tracked newQuotaUsages = null;
  @tracked newQuotaDuration = 86400; // 1 day default

  @action
  updateExistingQuotaTokens(quota, event) {
    quota.max_tokens = event.target.value;
  }

  @action
  updateExistingQuotaUsages(quota, event) {
    quota.max_usages = event.target.value;
  }

  @action
  updateExistingQuotaDuration(quota, value) {
    quota.duration_seconds = value;
  }

  get canAddQuota() {
    return (
      this.newQuotaGroupId &&
      (this.newQuotaTokens || this.newQuotaUsages) &&
      this.newQuotaDuration
    );
  }

  @action
  updateQuotaTokens(event) {
    this.newQuotaTokens = event.target.value;
  }

  @action
  updateQuotaUsages(event) {
    this.newQuotaUsages = event.target.value;
  }

  @action
  updateQuotaDuration(event) {
    this.newQuotaDuration = event.target.value;
  }

  @action
  updateGroups(groups) {
    this.newQuotaGroupIds = groups;
  }

  @action
  async addQuota() {
    const quota = {
      group_id: this.newQuotaGroupIds[0],
      group_name: this.site.groups.findBy("id", this.newQuotaGroupIds[0]).name,
      llm_model_id: this.args.model.id,
      max_tokens: this.newQuotaTokens,
      max_usages: this.newQuotaUsages,
      duration_seconds: this.newQuotaDuration,
    };
    this.args.model.llm_quotas.pushObject(quota);
  }

  @action
  async deleteQuota(quota) {
    this.args.model.llm_quotas.removeObject(quota);
  }

  <template>
    <div class="ai-llm-quotas">
      <table class="ai-llm-quotas__table">
        <thead class="ai-llm-quotas__table-head">
          <tr class="ai-llm-quotas__header-row">
            <th class="ai-llm-quotas__header">{{I18n.t
                "discourse_ai.llms.quotas.group"
              }}</th>
            <th class="ai-llm-quotas__header">{{I18n.t
                "discourse_ai.llms.quotas.max_tokens"
              }}</th>
            <th class="ai-llm-quotas__header">{{I18n.t
                "discourse_ai.llms.quotas.max_usages"
              }}</th>
            <th class="ai-llm-quotas__header">{{I18n.t
                "discourse_ai.llms.quotas.duration"
              }}</th>
            <th
              class="ai-llm-quotas__header ai-llm-quotas__header--actions"
            ></th>
          </tr>
        </thead>
        <tbody class="ai-llm-quotas__table-body">
          {{#each @model.llm_quotas as |quota|}}
            <tr class="ai-llm-quotas__row">
              <td class="ai-llm-quotas__cell">{{quota.group_name}}</td>
              <td class="ai-llm-quotas__cell">
                <input
                  type="number"
                  value={{quota.max_tokens}}
                  class="ai-llm-quotas__input"
                  min="1"
                  {{on "input" (fn this.updateExistingQuotaTokens quota)}}
                />
              </td>
              <td class="ai-llm-quotas__cell">
                <input
                  type="number"
                  value={{quota.max_usages}}
                  class="ai-llm-quotas__input"
                  min="1"
                  {{on "input" (fn this.updateExistingQuotaUsages quota)}}
                />
              </td>
              <td class="ai-llm-quotas__cell">
                <DurationSelector
                  @value={{quota.duration_seconds}}
                  @onChange={{fn this.updateExistingQuotaDuration quota}}
                />
              </td>
              <td class="ai-llm-quotas__cell ai-llm-quotas__cell--actions">
                <DButton
                  @icon="trash-alt"
                  class="btn-danger ai-llm-quotas__delete-btn"
                  {{on "click" (fn this.deleteQuota quota)}}
                />
              </td>
            </tr>
          {{/each}}
          <tr class="ai-llm-quotas__row ai-llm-quotas__row--new">
            <td class="ai-llm-quotas__cell">
              <GroupChooser
                @value={{this.newQuotaGroupIds}}
                @content={{this.site.groups}}
                @onChange={{this.updateGroups}}
                @options={{hash maximum=1}}
              />
            </td>
            <td class="ai-llm-quotas__cell">
              <input
                type="number"
                value={{this.newQuotaTokens}}
                class="ai-llm-quotas__input"
                {{on "input" this.updateQuotaTokens}}
                min="1"
              />
            </td>
            <td class="ai-llm-quotas__cell">
              <input
                type="number"
                value={{this.newQuotaUsages}}
                class="ai-llm-quotas__input"
                {{on "input" this.updateQuotaUsages}}
                min="1"
              />
            </td>
            <td class="ai-llm-quotas__cell">
              <input
                type="number"
                value={{this.newQuotaDuration}}
                class="ai-llm-quotas__input"
                {{on "input" this.updateQuotaDuration}}
                min="1"
              />
            </td>
            <td class="ai-llm-quotas__cell ai-llm-quotas__cell--actions">
              <DButton
                @action={{this.addQuota}}
                @icon="plus"
                class="btn-primary ai-llm-quotas__add-btn"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </template>
}
