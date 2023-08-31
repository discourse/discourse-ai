import Component from '@glimmer/component';
import DButton from "discourse/components/d-button";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import I18n from "I18n";

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

  closeMenu() {
    this.suggestIcon = "discourse-sparkles";
    this.showMenu = false;
  }

  @bind
  onClickOutside(event) {
    const menu = document.querySelector(".ai-title-suggestions-menu");

    if (event.target === menu) {
      return;
    }

    return this.closeMenu();
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
      return this.closeMenu();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.category) {
    const selectedCategoryId = this.site.categories.find((c) => c.slug === suggestion).id;
    composer.set("categoryId", selectedCategoryId);
    return this.closeMenu();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.tag) {
      this.updateTags(suggestion, composer);
    }
  }

  updateTags(suggestion, composer) {
    const maxTags = this.siteSettings.max_tags_per_topic;

    if (!composer.tags) {
      composer.set("tags", [suggestion]);
      this.generatedSuggestions = this.generatedSuggestions.filter((s) => s !== suggestion);
      return;
    }
    const tags = composer.tags;

    if (tags >= maxTags) {
      return;
    }

    // TODO: FIX, UI is not updating after adding a tag, though it works on submit.
    tags.push(suggestion);
    composer.set("tags", tags);
    return this.generatedSuggestions = this.generatedSuggestions.filter((s) => s !== suggestion);
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
      if (this.args.mode === this.SUGGESTION_TYPES.title) {
        this.generatedSuggestions = data.suggestions;
      } else {
        this.generatedSuggestions = data.assistant.map((s) => s.name);
      }
    }).catch(popupAjaxError).finally(() => {
      this.loading = false;
      this.suggestIcon = "sync-alt";
      this.showMenu = true;
    });

  }
}