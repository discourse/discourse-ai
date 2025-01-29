import Component from "@glimmer/component";
import { action } from "@ember/object";
import BackButton from "discourse/components/back-button";
import AiLlmEditorForm from "./ai-llm-editor-form";

export default class AiLlmEditor extends Component {
  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-llms"
      @label="discourse_ai.llms.back"
    />
    <AiLlmEditorForm
      @model={{@model}}
      @llmTemplate={{@llmTemplate}}
      @llms={{@llms}}
    />
  </template>
}
