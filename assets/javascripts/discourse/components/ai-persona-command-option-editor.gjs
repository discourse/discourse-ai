import { Input } from "@ember/component";

const AiPersonaCommandOptionEditor = <template>
  <div class="control-group ai-persona-command-option-editor">
    <label>
      {{@option.name}}
    </label>
    <div class="">
      <Input @value={{@option.value.value}} />
    </div>
    <div class="ai-persona-command-option-editor__instructions">
      {{@option.description}}
    </div>
  </div>
</template>;

export default AiPersonaCommandOptionEditor;
