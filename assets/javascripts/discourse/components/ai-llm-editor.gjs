import Component from "@glimmer/component";
import { action } from "@ember/object";
import BackButton from "discourse/components/back-button";
import AiLlmEditorForm from "./ai-llm-editor-form";

export default class AiLlmEditor extends Component {
  constructor() {
    super(...arguments);
    if (this.args.llmTemplate) {
      this.configurePreset();
    }
  }

  @action
  configurePreset() {
    let [id, model] = this.args.llmTemplate.split(/-(.*)/);
    if (id === "none") {
      return;
    }

    const info = this.args.llms.resultSetMeta.presets.findBy("id", id);
    const modelInfo = info.models.findBy("name", model);

    this.args.model.setProperties({
      max_prompt_tokens: modelInfo.tokens,
      tokenizer: info.tokenizer,
      url: modelInfo.endpoint || info.endpoint,
      display_name: modelInfo.display_name,
      name: modelInfo.name,
      provider: info.provider,
    });
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-llms"
      @label="discourse_ai.llms.back"
    />
    <AiLlmEditorForm @model={{@model}} @llms={{@llms}} />
  </template>
}
