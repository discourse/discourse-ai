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


export default class AITitleSuggester extends Component {
  <template>
    <DButton
      @class="suggest-titles-button {{if this.loading 'is-loading'}}"
      @icon={{this.suggestTitleIcon}}
      @title="discourse_ai.ai_helper.suggest_titles"
      @action={{this.suggestTitles}}
      @disabled={{this.disableSuggestionButton}}
    />
    {{#if this.showMenu}}
      {{! template-lint-disable modifier-name-case }}
      <ul class="popup-menu ai-title-suggestions-menu" {{didInsert this.handleClickOutside}}>
        {{#each this.generatedTitleSuggestions as |suggestion index|}}
          <li data-name={{suggestion}} data-value={{index}}>
              <DButton
                @class="popup-menu-btn"
                @translatedLabel={{suggestion}}
                @action={{this.updateTopicTitle}}
                @actionParam={{suggestion}}
              />
          </li>
        {{/each}}
      </ul>
    {{/if}}
  </template>

  @service dialog;
  @tracked loading = false;
  @tracked showMenu = false;
  @tracked generatedTitleSuggestions = [];
  @tracked suggestTitleIcon = "discourse-sparkles";
  mode = {
    id: -2,
    name: "generate_titles",
    translated_name: "Suggest topic titles",
    prompt_type: "list"
  };

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("click", this.onClickOutside);
  }

  get composerInput() {
    return document.querySelector(".d-editor-input")?.value || this.args.outletArgs.composer.reply;
  }

  get disableSuggestionButton() {
    return this.loading;
  }

  closeMenu() {
    this.suggestTitleIcon = "discourse-sparkles";
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
  updateTopicTitle(title) {
    const composer = this.args.outletArgs?.composer;

    if (composer) {
      composer.set("title", title);
      this.closeMenu();
    }
  }

  @action
  async suggestTitles() {
    if (this.composerInput?.length === 0) {
      return this.dialog.alert(I18n.t("discourse_ai.ai_helper.missing_content"));
    }

    this.loading = true;
    this.suggestTitleIcon = "spinner";

    return ajax("/discourse-ai/ai-helper/suggest_tags", {
      method: "POST",
      data: { text: this.composerInput },
    }).then((data) => {
      console.log(data);
      this.generatedTitleSuggestions = data.suggestions;
    }).catch((e) => {
      console.log(e);
    }).finally(() => {
      this.loading = false;
      this.suggestTitleIcon = "sync-alt";
      this.showMenu = true;
    });

  }
}