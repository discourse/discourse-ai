import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";
import { MIN_CHARACTER_COUNT } from "../../lib/ai-helper-suggestions";

export default class AiTitleSuggester extends Component {
  @service siteSettings;
  @tracked loading = false;
  @tracked suggestions = null;
  @tracked untriggers = [];
  @tracked triggerIcon = "discourse-sparkles";

  get showSuggestionButton() {
    const composerFields = document.querySelector(".composer-fields");
    const showTrigger = this.args.composer.reply?.length > MIN_CHARACTER_COUNT;

    if (composerFields) {
      if (showTrigger) {
        composerFields.classList.add("showing-ai-suggestions");
      } else {
        composerFields.classList.remove("showing-ai-suggestions");
      }
    }

    return this.siteSettings.ai_embeddings_enabled && showTrigger;
  }

  @action
  async loadSuggestions() {
    if (this.suggestions && !this.dMenu.expanded) {
      return this.suggestions;
    }

    this.loading = true;
    this.triggerIcon = "spinner";

    try {
      const { suggestions } = await ajax(
        "/discourse-ai/ai-helper/suggest_title",
        {
          method: "POST",
          data: { text: this.args.composer.reply },
        }
      );
      this.suggestions = suggestions;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
      this.triggerIcon = "sync-alt";
    }

    return this.suggestions;
  }

  @action
  applySuggestion(suggestion) {
    const composer = this.args.composer;
    if (!composer) {
      return;
    }

    composer.set("title", suggestion);
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  onClose() {
    this.triggerIcon = "discourse-sparkles";
  }

  <template>
    {{#if this.showSuggestionButton}}
      <DMenu
        @title={{i18n "discourse_ai.ai_helper.suggest"}}
        @icon={{this.triggerIcon}}
        @identifier="ai-title-suggester"
        @onClose={{this.onClose}}
        @triggerClass="suggestion-button suggest-titles-button {{if
          this.loading
          'is-loading'
        }}"
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @untriggers={{this.untriggers}}
        {{on "click" this.loadSuggestions}}
      >
        <:content>
          {{#unless this.loading}}
            <DropdownMenu as |dropdown|>
              {{#each this.suggestions as |suggestion|}}
                <dropdown.item>
                  <DButton
                    data-title={{suggestion}}
                    title={{suggestion}}
                    @action={{fn this.applySuggestion suggestion}}
                  >
                    {{suggestion}}
                  </DButton>
                </dropdown.item>
              {{/each}}
            </DropdownMenu>
          {{/unless}}
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
