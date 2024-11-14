import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import categoryBadge from "discourse/helpers/category-badge";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";

export default class AiCategorySuggester extends Component {
  @service siteSettings;
  @tracked loading = false;
  @tracked suggestions = null;
  @tracked untriggers = [];
  @tracked triggerIcon = "discourse-sparkles";

  get referenceText() {
    if (this.args.composer?.reply) {
      return this.args.composer.reply;
    }

    console.log(this.args);
    ajax(`/raw/${this.args.topic.id}/1.json`).then((response) => {
      console.log(response);
    });

    return "abcdefhg";
  }

  get showSuggestionButton() {
    const MIN_CHARACTER_COUNT = 40;
    const composerFields = document.querySelector(".composer-fields");
    const showTrigger = this.referenceText.length > MIN_CHARACTER_COUNT;

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
      const { assistant } = await ajax(
        "/discourse-ai/ai-helper/suggest_category",
        {
          method: "POST",
          data: { text: this.args.composer.reply },
        }
      );
      this.suggestions = assistant;
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

    composer.set("categoryId", suggestion.id);
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
        @identifier="ai-category-suggester"
        @onClose={{this.onClose}}
        @triggerClass="suggestion-button suggest-category-button {{if
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
                    class="category-row"
                    data-title={{suggestion.name}}
                    data-value={{suggestion.id}}
                    title={{suggestion.name}}
                    @action={{fn this.applySuggestion suggestion}}
                  >
                    <div class="category-status">
                      {{categoryBadge suggestion}}
                      <span class="topic-count" aria-label="">x
                        {{suggestion.topicCount}}</span>
                    </div>
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
