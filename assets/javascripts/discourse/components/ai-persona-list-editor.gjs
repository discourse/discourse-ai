import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DSelect from "discourse/components/d-select";
import DropdownMenu from "discourse/components/dropdown-menu";
import FilterInput from "discourse/components/filter-input";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import DMenu from "float-kit/components/d-menu";
import AiPersonaEditor from "./ai-persona-editor";

const LAYOUT_BUTTONS = [
  {
    id: "table",
    label: "discourse_ai.layout.table",
    icon: "discourse-table",
  },
  {
    id: "card",
    label: "discourse_ai.layout.card",
    icon: "table",
  },
];

export default class AiPersonaListEditor extends Component {
  @service adminPluginNavManager;
  @service keyValueStore;
  @service capabilities;

  @tracked filterValue = "";
  @tracked featureFilter = "all";
  @tracked currentLayout = LAYOUT_BUTTONS[0];

  constructor() {
    super(...arguments);
    const savedLayoutId = this.keyValueStore.get("ai-persona-list-layout");
    if (savedLayoutId) {
      const found = LAYOUT_BUTTONS.find((b) => b.id === savedLayoutId);
      if (found) {
        this.currentLayout = found;
      }
    }
  }

  get filteredPersonas() {
    let personas = this.args.personas || [];

    // Filter by feature if not "all"
    if (this.featureFilter !== "all") {
      personas = personas.filter((persona) =>
        (persona.features || []).some(
          (feature) => feature.name === this.featureFilter
        )
      );
    }

    // Filter by search term if present
    if (this.filterValue) {
      const term = this.filterValue.toLowerCase();
      personas = personas.filter((persona) => {
        const textMatches =
          persona.name?.toLowerCase().includes(term) ||
          persona.description?.toLowerCase().includes(term);

        const featureMatches = (persona.features || []).some((feature) =>
          feature.name?.toLowerCase().includes(term)
        );

        return textMatches || featureMatches;
      });
    }

    return personas;
  }

  get featureFilterOptions() {
    let features = [];
    (this.args.personas || []).forEach((persona) => {
      (persona.features || []).forEach((feature) => {
        if (feature?.name && !features.includes(feature.name)) {
          features.push(feature.name);
        }
      });
    });
    features.sort();
    return [
      {
        value: "all",
        label: i18n("discourse_ai.ai_persona.filters.all_features"),
      },
      ...features.map((name) => ({ value: name, label: name })),
    ];
  }

  @action
  async toggleEnabled(persona) {
    const oldValue = persona.enabled;
    const newValue = !oldValue;

    try {
      persona.set("enabled", newValue);
      await persona.save();
    } catch (err) {
      persona.set("enabled", oldValue);
      popupAjaxError(err);
    }
  }

  @action
  onNameFilterChange(event) {
    this.filterValue = event.target?.value || "";
  }

  @action
  onFeatureFilterChange(value) {
    this.featureFilter = value;
  }

  @action
  resetAndFocus() {
    this.filterValue = "";
    this.featureFilter = "all";
    document.querySelector(".admin-filter__input").focus();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onLayoutSelect(layoutId) {
    const found = LAYOUT_BUTTONS.find((b) => b.id === layoutId);
    if (found) {
      this.currentLayout = found;
      this.keyValueStore.set({
        key: "ai-persona-list-layout",
        value: layoutId,
      });
    }
    this.dMenu.close();
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/{{this.adminPluginNavManager.currentPlugin.name}}/ai-personas"
      @label={{i18n "discourse_ai.ai_persona.short_title"}}
    />
    <section class="ai-persona-list-editor__current admin-detail">
      {{#if @currentPersona}}
        <AiPersonaEditor @model={{@currentPersona}} @personas={{@personas}} />
      {{else}}
        <DPageSubheader
          @titleLabel={{i18n "discourse_ai.ai_persona.short_title"}}
          @descriptionLabel={{i18n
            "discourse_ai.ai_persona.persona_description"
          }}
          @learnMoreUrl="https://meta.discourse.org/t/ai-bot-personas/306099"
        >
          <:actions as |actions|>
            <actions.Primary
              @label="discourse_ai.ai_persona.new"
              @route="adminPlugins.show.discourse-ai-personas.new"
              @icon="plus"
              class="ai-persona-list-editor__new-button"
            />
          </:actions>
        </DPageSubheader>

        {{#if @personas}}
          <div class="ai-persona-list-editor__controls">
            <FilterInput
              placeholder={{i18n "discourse_ai.ai_persona.filters.text"}}
              @filterAction={{this.onNameFilterChange}}
              @value={{this.filterValue}}
              class="admin-filter__input"
              @icons={{hash left="magnifying-glass"}}
            />
            <DSelect
              @value={{this.featureFilter}}
              @includeNone={{false}}
              @onChange={{this.onFeatureFilterChange}}
              as |select|
            >
              {{#each this.featureFilterOptions as |option|}}
                <select.Option @value={{option.value}}>
                  {{option.label}}
                </select.Option>
              {{/each}}
            </DSelect>
            {{#if this.capabilities.viewport.md}}
              <DMenu
                @modalForMobile={{true}}
                @autofocus={{true}}
                @identifier="persona-list-layout"
                @onRegisterApi={{this.onRegisterApi}}
                @triggerClass="btn-default btn-icon"
              >
                <:trigger>
                  {{icon this.currentLayout.icon}}
                </:trigger>
                <:content>
                  <DropdownMenu as |dropdown|>
                    {{#each LAYOUT_BUTTONS as |button|}}
                      <dropdown.item>
                        <DButton
                          @label={{button.label}}
                          @icon={{button.icon}}
                          class="btn-transparent"
                          @action={{fn this.onLayoutSelect button.id}}
                        />
                      </dropdown.item>
                    {{/each}}
                  </DropdownMenu>
                </:content>
              </DMenu>
            {{/if}}
          </div>
        {{else}}
          <AdminConfigAreaEmptyList
            @ctaLabel="discourse_ai.ai_persona.new"
            @ctaRoute="adminPlugins.show.discourse-ai-personas.new"
            @ctaClass="ai-persona-list-editor__empty-new-button"
            @emptyLabel="discourse_ai.ai_persona.no_personas"
          />
        {{/if}}

        {{#if this.filteredPersonas}}
          <table
            class={{concatClass
              "content-list ai-persona-list-editor d-admin-table"
              (concat "--layout-" this.currentLayout.id)
            }}
          >
            <thead>
              <tr>
                <th>{{i18n "discourse_ai.ai_persona.name"}}</th>
                <th>{{i18n "discourse_ai.features.short_title"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.filteredPersonas as |persona|}}
                <tr
                  data-persona-id={{persona.id}}
                  class={{concatClass
                    "ai-persona-list__row d-admin-row__content"
                    (if persona.priority "--priority")
                    (if persona.enabled "--enabled")
                  }}
                >
                  <td class="d-admin-row__overview">
                    <div class="ai-persona-list__name-with-description">
                      <h3 class="ai-persona-list__name">
                        {{#if persona.user}}
                          {{avatar persona.user imageSize="tiny"}}
                        {{/if}}
                        {{persona.name}}
                      </h3>
                      <div class="ai-persona-list__description">
                        {{persona.description}}
                      </div>
                    </div>
                  </td>
                  <td class="d-admin-row__features">
                    {{#each persona.features as |feature|}}
                      <DButton
                        class="btn-flat btn-small ai-persona-list__row-item-feature"
                        @translatedLabel={{feature.name}}
                        @route="adminPlugins.show.discourse-ai-features.edit"
                        @routeModels={{feature.id}}
                      />
                    {{/each}}
                  </td>
                  <td class="d-admin-row__controls">
                    <LinkTo
                      @route="adminPlugins.show.discourse-ai-personas.edit"
                      @model={{persona}}
                      class="btn btn-text btn-small"
                    >{{i18n "discourse_ai.ai_persona.edit"}} </LinkTo>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <div class="ai-persona-list-editor__no-results">

            <h3>{{i18n "discourse_ai.ai_persona.filters.no_results"}}</h3>

            <DButton
              @icon="arrow-rotate-left"
              @label="discourse_ai.ai_persona.filters.reset"
              @action={{this.resetAndFocus}}
              class="btn-default"
            />
          </div>
        {{/if}}
      {{/if}}
    </section>
  </template>
}
