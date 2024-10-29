import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class AiGistToggle extends Component {
  @service router;
  @service gistPreference;

  get shouldShow() {
    return this.router.currentRoute.attributes?.list?.topics?.some(
      (topic) => topic.ai_topic_gist
    );
  }

  get buttons() {
    return [
      {
        id: "gists_enabled",
        label: "discourse_ai.summarization.gists_enabled_long",
        icon: "discourse-sparkles",
      },
      {
        id: "gists_disabled",
        label: "discourse_ai.summarization.gists_disabled",
        icon: "far-eye-slash",
      },
    ];
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onSelect(optionId) {
    this.gistPreference.setPreference(optionId);
    this.dMenu.close();
  }

  <template>
    {{#if this.shouldShow}}

      <DMenu
        @modalForMobile={{true}}
        @autofocus={{true}}
        @identifier="ai-gists-dropdown"
        @onRegisterApi={{this.onRegisterApi}}
        @triggerClass="btn-transparent"
      >
        <:trigger>
          <span class="d-button-label">
            {{i18n
              (concat
                "discourse_ai.summarization." this.gistPreference.preference
              )
            }}
          </span>
          {{icon "angle-down"}}
        </:trigger>
        <:content>
          <DropdownMenu as |dropdown|>
            {{#each this.buttons as |button|}}
              <dropdown.item>
                <DButton
                  @label={{button.label}}
                  @icon={{button.icon}}
                  class="btn-transparent"
                  @action={{fn this.onSelect button.id}}
                />
              </dropdown.item>
            {{/each}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
