import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import AiFeaturesList from "./ai-features-list";

const CONFIGURED = "configured";
const UNCONFIGURED = "unconfigured";

export default class AiFeatures extends Component {
  @service adminPluginNavManager;

  @tracked selectedFeatureGroup = CONFIGURED;

  constructor() {
    super(...arguments);

    if (this.configuredFeatures.length === 0) {
      this.selectedFeatureGroup = UNCONFIGURED;
    }
  }

  get featureGroups() {
    return [
      { id: CONFIGURED, label: "discourse_ai.features.nav.configured" },
      { id: UNCONFIGURED, label: "discourse_ai.features.nav.unconfigured" },
    ];
  }

  get configuredFeatures() {
    return this.args.features.filter(
      (feature) => feature.module_enabled === true
    );
  }

  get unconfiguredFeatures() {
    return this.args.features.filter(
      (feature) => feature.module_enabled === false
    );
  }

  @action
  selectFeatureGroup(groupId) {
    this.selectedFeatureGroup = groupId;
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-features"
      @label={{i18n "discourse_ai.features.short_title"}}
    />
    <section class="ai-features admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.features.short_title"}}
        @descriptionLabel={{i18n "discourse_ai.features.description"}}
        @learnMoreUrl="todo"
      />

      <div class="ai-feature-groups">
        {{#each this.featureGroups as |groupData|}}
          <DButton
            class={{concatClass
              groupData.id
              (if
                (eq this.selectedFeatureGroup groupData.id)
                "btn-primary"
                "btn-default"
              )
            }}
            @action={{fn this.selectFeatureGroup groupData.id}}
            @label={{groupData.label}}
          />
        {{/each}}
      </div>

      {{#if (eq this.selectedFeatureGroup "configured")}}
        <AiFeaturesList @modules={{this.configuredFeatures}} />
      {{else}}
        <AiFeaturesList @modules={{this.unconfiguredFeatures}} />
      {{/if}}
    </section>
  </template>
}
