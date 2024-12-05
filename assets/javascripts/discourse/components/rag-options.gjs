import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DTooltip from "discourse/components/d-tooltip";
import I18n from "discourse-i18n";

export default class RagOptions extends Component {
  @tracked showIndexingOptions = false;

  @action
  toggleIndexingOptions(event) {
    this.showIndexingOptions = !this.showIndexingOptions;
    event.preventDefault();
    event.stopPropagation();
  }

  get indexingOptionsText() {
    return this.showIndexingOptions
      ? I18n.t("discourse_ai.rag.options.hide_indexing_options")
      : I18n.t("discourse_ai.rag.options.show_indexing_options");
  }

  <template>
    {{#if @model.rag_uploads}}
      <a
        href="#"
        class="rag-options__indexing-options"
        {{on "click" this.toggleIndexingOptions}}
      >{{this.indexingOptionsText}}</a>
    {{/if}}

    {{#if this.showIndexingOptions}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.rag.options.rag_chunk_tokens"}}</label>
        <Input
          @type="number"
          step="any"
          lang="en"
          class="rag-options__rag_chunk_tokens"
          @value={{@model.rag_chunk_tokens}}
        />
        <DTooltip
          @icon="circle-question"
          @content={{I18n.t "discourse_ai.rag.options.rag_chunk_tokens_help"}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t
            "discourse_ai.rag.options.rag_chunk_overlap_tokens"
          }}</label>
        <Input
          @type="number"
          step="any"
          lang="en"
          class="rag-options__rag_chunk_overlap_tokens"
          @value={{@model.rag_chunk_overlap_tokens}}
        />
        <DTooltip
          @icon="circle-question"
          @content={{I18n.t
            "discourse_ai.rag.options.rag_chunk_overlap_tokens_help"
          }}
        />
      </div>
      {{yield}}
    {{/if}}
  </template>
}
