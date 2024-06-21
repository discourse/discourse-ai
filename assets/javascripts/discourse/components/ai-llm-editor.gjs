import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import AiLlmEditorForm from "./ai-llm-editor-form";

export default class AiLlmEditor extends Component {
  @tracked presetConfigured = false;
  presetId = "none";

  get showPresets() {
    return (
      this.args.model.isNew && !this.presetConfigured && !this.args.model.url
    );
  }

  get preConfiguredLlms() {
    let options = [
      {
        id: "none",
        name: I18n.t(`discourse_ai.llms.preconfigured.none`),
      },
    ];

    this.args.llms.resultSetMeta.presets.forEach((llm) => {
      if (llm.models) {
        llm.models.forEach((model) => {
          options.push({
            id: `${llm.id}-${model.name}`,
            name: model.display_name,
          });
        });
      }
    });

    return options;
  }

  @action
  configurePreset() {
    this.presetConfigured = true;

    let [id, model] = this.presetId.split(/-(.*)/);
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
    {{#if this.showPresets}}
      <form class="form-horizontal ai-llm-editor">
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.llms.preconfigured_llms"}}</label>
          <ComboBox
            @value={{this.presetId}}
            @content={{this.preConfiguredLlms}}
            class="ai-llm-editor__presets"
          />
        </div>

        <div class="control-group ai-llm-editor__action_panel">
          <DButton class="ai-llm-editor__next" @action={{this.configurePreset}}>
            {{I18n.t "discourse_ai.llms.next.title"}}
          </DButton>
        </div>
      </form>
    {{else}}
      <AiLlmEditorForm @model={{@model}} @llms={{@llms}} />
    {{/if}}
  </template>
}
