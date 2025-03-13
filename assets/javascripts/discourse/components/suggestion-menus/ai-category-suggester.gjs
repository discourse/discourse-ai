import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import categoryBadge from "discourse/helpers/category-badge";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import { MIN_CHARACTER_COUNT } from "../../lib/ai-helper-suggestions";

export default class AiCategorySuggester extends Component {
  @service siteSettings;
  @tracked loading = false;
  @tracked suggestions = null;
  @tracked untriggers = [];
  @tracked triggerIcon = "discourse-sparkles";
  @tracked content = null;

  get showSuggestionButton() {
    const composerFields = document.querySelector(".composer-fields");
    this.content = this.args.composer?.reply;
    const showTrigger =
      this.content?.length > MIN_CHARACTER_COUNT ||
      this.args.topicState === "edit";

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

    const data = {};

    if (this.content) {
      data.text = this.content;
    } else {
      data.topic_id = this.args.buffered.content.id;
    }

    try {
      const { assistant } = await ajax(
        "/discourse-ai/ai-helper/suggest_category",
        {
          method: "POST",
          data,
        }
      );
      this.suggestions = assistant;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
      this.triggerIcon = "rotate";
    }

    return this.suggestions;
  }

  @action
  applySuggestion(suggestion) {
    const composer = this.args.composer;
    const buffered = this.args.buffered;

    if (composer) {
      composer.set("categoryId", suggestion.id);
      composer.get("categoryId");
    }

    if (buffered) {
      this.args.buffered.set("category_id", suggestion.id);
    }

    return this.dMenu.close();
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
        @triggerClass="btn-transparent suggestion-button suggest-category-button {{if
          this.loading
          'is-loading'
        }}"
        @contentClass="ai-suggestions-menu"
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @untriggers={{this.untriggers}}
        {{on "click" this.loadSuggestions}}
      >
        <:content>
          {{#unless this.loading}}
            <DropdownMenu as |dropdown|>
              {{#each this.suggestions as |suggestion index|}}
                <dropdown.item>
                  <DButton
                    class="category-row"
                    data-name={{suggestion.name}}
                    data-value={{index}}
                    title={{suggestion.name}}
                    @action={{fn this.applySuggestion suggestion}}
                  >
                    <div class="category-status">
                      {{categoryBadge suggestion}}
                      <span class="topic-count">x
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
