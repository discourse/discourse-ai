import Component from '@glimmer/component';
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import DButton from "discourse/components/d-button";

export default class AISuggestionDropdown extends Component {
  <template>
    <DButton
      @class="suggestion-button {{if this.loading 'is-loading'}}"
      @icon={{this.suggestIcon}}
      @title="discourse_ai.ai_helper.suggest"
      @action={{this.performSuggestion}}
      @disabled={{this.disableSuggestionButton}}
      ...attributes
    />
    {{#if this.showMenu}}
      {{! template-lint-disable modifier-name-case }}
      <ul class="popup-menu ai-suggestions-menu" {{didInsert this.handleClickOutside}}>
        {{#if this.showErrors}}
          <li class="ai-suggestions-menu__errors">{{this.error}}</li>
        {{/if}}
        {{#each this.generatedSuggestions as |suggestion index|}}
          <li data-name={{suggestion}} data-value={{index}}>
              <DButton
                @class="popup-menu-btn"
                @translatedLabel={{suggestion}}
                @action={{this.applySuggestion}}
                @actionParam={{suggestion}}
              />
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </template>

  @service dialog;
  @service site;
  @service siteSettings;
  @tracked loading = false;
  @tracked showMenu = false;
  @tracked generatedSuggestions = [];
  @tracked suggestIcon = "discourse-sparkles";
  @tracked showErrors = false;
  @tracked error = "";
  SUGGESTION_TYPES = {
    title: "suggest_title",
    category: "suggest_category",
    tag: "suggest_tags",
  };

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("click", this.onClickOutside);
  }

  get composerInput() {
    return document.querySelector(".d-editor-input")?.value || this.args.composer.reply;
  }

  get disableSuggestionButton() {
    return this.loading;
  }

  @bind
  onClickOutside(event) {
    const menu = document.querySelector(".ai-title-suggestions-menu");

    if (event.target === menu) {
      return;
    }

    return this.#closeMenu();
  }

  @action
  handleClickOutside() {
    document.addEventListener("click", this.onClickOutside);
  }

  @action
  applySuggestion(suggestion) {
    if (!this.args.mode) {
      return;
    }

    const composer = this.args?.composer;
    if (!composer) {
      return;
    }


    if (this.args.mode === this.SUGGESTION_TYPES.title) {
      composer.set("title", suggestion);
      return this.#closeMenu();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.category) {
    const selectedCategoryId = this.site.categories.find((c) => c.slug === suggestion).id;
    composer.set("categoryId", selectedCategoryId);
    return this.#closeMenu();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.tag) {
      this.#updateTags(suggestion, composer);
    }
  }

  @action
  async performSuggestion() {
    if (!this.args.mode) {
      return;
    }

    if (this.composerInput?.length === 0) {
      return this.dialog.alert(I18n.t("discourse_ai.ai_helper.missing_content"));
    }

    this.loading = true;
    this.suggestIcon = "spinner";

    return ajax(`/discourse-ai/ai-helper/${this.args.mode}`, {
      method: "POST",
      data: { text: this.composerInput },
    }).then((data) => {
      this.#assignGeneratedSuggestions(data, this.args.mode);
    }).catch(popupAjaxError).finally(() => {
      this.loading = false;
      this.suggestIcon = "sync-alt";
      this.showMenu = true;
    });
  }

  #closeMenu() {
    this.suggestIcon = "discourse-sparkles";
    this.showMenu = false;
    this.showErrors = false;
    this.errors = "";
  }

  #updateTags(suggestion, composer) {
    const maxTags = this.siteSettings.max_tags_per_topic;

    if (!composer.tags) {
      composer.set("tags", [suggestion]);
      // remove tag from the list of suggestions once added
      this.generatedSuggestions = this.generatedSuggestions.filter((s) => s !== suggestion);
      return;
    }
    const tags = composer.tags;

    if (tags?.length >= maxTags) {
      // Show error if trying to add more tags than allowed
      this.showErrors = true;
      this.error = I18n.t("select_kit.max_content_reached", { count: maxTags});
      return;
    }

    tags.push(suggestion);
    composer.set("tags", [...tags]);
    // remove tag from the list of suggestions once added
    return this.generatedSuggestions = this.generatedSuggestions.filter((s) => s !== suggestion);
  }

  #tagSelectorHasValues() {
    return this.args.composer?.tags && this.args.composer?.tags.length > 0;
  }

  #assignGeneratedSuggestions(data, mode) {
    if (mode === this.SUGGESTION_TYPES.title) {
      return this.generatedSuggestions = data.suggestions;
    }

    const suggestions = data.assistant.map((s) => s.name);

    if (mode === this.SUGGESTION_TYPES.tag) {
      if (this.#tagSelectorHasValues()) {
        // Filter out tags if they are already selected in the tag input
        return this.generatedSuggestions = suggestions.filter((t) => !this.args.composer.tags.includes(t));
      } else {
        return this.generatedSuggestions = suggestions;
      }
    }

    return this.generatedSuggestions = suggestions;
  }
}