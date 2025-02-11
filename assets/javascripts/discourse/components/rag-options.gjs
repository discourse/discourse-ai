import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DTooltip from "discourse/components/d-tooltip";
import { i18n } from "discourse-i18n";
import AiLlmSelector from "./ai-llm-selector";

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
      ? i18n("discourse_ai.rag.options.hide_indexing_options")
      : i18n("discourse_ai.rag.options.show_indexing_options");
  }

  get visionLlms() {
    return this.args.llms.filter((llm) => llm.vision_enabled);
  }

  get visionLlmId() {
    return this.args.model.rag_llm_model_id || "blank";
  }

  set visionLlmId(value) {
    if (value === "blank") {
      this.args.model.rag_llm_model_id = null;
    } else {
      this.args.model.rag_llm_model_id = value;
    }
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
        <label>{{i18n "discourse_ai.rag.options.rag_chunk_tokens"}}</label>
        <Input
          @type="number"
          step="any"
          lang="en"
          class="rag-options__rag_chunk_tokens"
          @value={{@model.rag_chunk_tokens}}
        />
        <DTooltip
          @icon="circle-question"
          @content={{i18n "discourse_ai.rag.options.rag_chunk_tokens_help"}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n
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
          @content={{i18n
            "discourse_ai.rag.options.rag_chunk_overlap_tokens_help"
          }}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.rag.options.rag_llm_model"}}</label>
        <AiLlmSelector
          class="ai-persona-editor__llms"
          @value={{this.visionLlmId}}
          @llms={{this.visionLlms}}
        />
        <DTooltip
          @icon="circle-question"
          @content={{i18n "discourse_ai.rag.options.rag_llm_model_help"}}
        />
      </div>
      {{yield}}
    {{/if}}
  </template>
}
