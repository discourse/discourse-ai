import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import categoryBadge from "discourse/helpers/category-badge";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";
import eq from "truth-helpers/helpers/eq";

export default class AiSplitTopicSuggester extends Component {
  @service site;
  @service menu;
  @tracked suggestions = [];
  @tracked loading = false;
  @tracked icon = "discourse-sparkles";
  SUGGESTION_TYPES = {
    title: "suggest_title",
    category: "suggest_category",
    tag: "suggest_tags",
  };

  constructor() {
    super(...arguments);
  }

  get input() {
    return this.args.selectedPosts.map((item) => item.cooked).join("\n");
  }

  get disabled() {
    return this.loading || this.suggestions.length > 0;
  }

  @action
  loadSuggestions() {
    if (this.loading || this.suggestions.length > 0) {
      return;
    }

    this.loading = true;
    this.icon = "spinner";

    ajax(`/discourse-ai/ai-helper/${this.args.mode}`, {
      method: "POST",
      data: { text: this.input },
    })
      .then((result) => {
        if (this.args.mode === this.SUGGESTION_TYPES.title) {
          this.suggestions = result.suggestions;
        } else if (this.args.mode === this.SUGGESTION_TYPES.category) {
          const suggestions = result.assistant.map((s) => s.name);
          const suggestedCategories = this.site.categories.filter((item) =>
            suggestions.includes(item.name.toLowerCase())
          );
          this.suggestions = suggestedCategories;
        } else {
          this.suggestions = result.assistant.map((s) => s.name);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
        this.icon = "discourse-sparkles";
      });
  }

  @action
  applySuggestion(suggestion) {
    if (!this.args.mode) {
      return;
    }

    if (this.args.mode === this.SUGGESTION_TYPES.title) {
      this.args.updateAction(suggestion);
      return this.menu.close();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.category) {
      this.args.updateAction(suggestion.id);
      return this.menu.close();
    }

    if (this.args.mode === this.SUGGESTION_TYPES.tag) {
      if (this.args.currentValue) {
        if (Array.isArray(this.args.currentValue)) {
          const updatedTags = [...this.args.currentValue, suggestion];
          this.args.updateAction([...new Set(updatedTags)]);
        } else {
          const updatedTags = [this.args.currentValue, suggestion];
          this.args.updateAction([...new Set(updatedTags)]);
        }
      } else {
        this.args.updateAction(suggestion);
      }
      return this.menu.close();
    }
  }

  <template>
    <DMenu @interactive={{true}} class="ai-split-topic-suggestion-button">
      <:trigger>
        <div {{on "click" (fn this.loadSuggestions)}}>
          {{icon this.icon}}
        </div>
      </:trigger>
      <:content>
        {{#unless this.loading}}
          <ul class="ai-split-topic-suggestion__results">
            {{#each this.suggestions as |suggestion index|}}
              {{#if (eq @mode "suggest_category")}}
                <li
                  data-name={{suggestion.name}}
                  data-value={{suggestion.id}}
                  class="ai-split-topic-suggestion__category-result"
                  {{on "click" (fn this.applySuggestion suggestion)}}
                >
                  {{categoryBadge suggestion}}
                </li>

              {{else}}
                <li data-name={{suggestion}} data-value={{index}}>
                  <DButton
                    @translatedLabel={{suggestion}}
                    @action={{this.applySuggestion}}
                    @actionParam={{suggestion}}
                  />
                </li>
              {{/if}}
            {{/each}}
          </ul>
        {{/unless}}
      </:content>
    </DMenu>
  </template>
}
