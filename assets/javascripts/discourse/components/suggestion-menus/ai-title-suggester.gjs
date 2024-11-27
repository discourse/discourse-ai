import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import DMenu from "float-kit/components/d-menu";
import { MIN_CHARACTER_COUNT } from "../../lib/ai-helper-suggestions";

export default class AiTitleSuggester extends Component {
  @tracked loading = false;
  @tracked suggestions = null;
  @tracked untriggers = [];
  @tracked triggerIcon = "discourse-sparkles";
  @tracked content = null;
  @tracked topicContent = null;

  constructor() {
    super(...arguments);

    if (!this.topicContent && this.args.composer?.reply === undefined) {
      this.fetchTopicContent();
    }
  }

  async fetchTopicContent() {
    await ajax(`/t/${this.args.buffered.content.id}.json`).then(
      ({ post_stream }) => {
        this.topicContent = post_stream.posts[0].cooked;
      }
    );
  }

  get showSuggestionButton() {
    const composerFields = document.querySelector(".composer-fields");
    const editTopicTitleField = document.querySelector(".edit-topic-title");

    this.content = this.args.composer?.reply || this.topicContent;
    const showTrigger = this.content?.length > MIN_CHARACTER_COUNT;

    if (composerFields) {
      if (showTrigger) {
        composerFields.classList.add("showing-ai-suggestions");
      } else {
        composerFields.classList.remove("showing-ai-suggestions");
      }
    }

    if (editTopicTitleField) {
      if (showTrigger) {
        editTopicTitleField.classList.add("showing-ai-suggestions");
      } else {
        editTopicTitleField.classList.remove("showing-ai-suggestions");
      }
    }

    return showTrigger;
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
          data: { text: this.content },
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
    const model = this.args.composer ? this.args.composer : this.args.buffered;
    if (!model) {
      return;
    }

    model.set("title", suggestion);
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
