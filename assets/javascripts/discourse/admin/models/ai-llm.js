import RestModel from "discourse/models/rest";

export default class AiLlm extends RestModel {
  createProperties() {
    return this.getProperties(
      "id",
      "display_name",
      "name",
      "provider",
      "tokenizer",
      "max_prompt_tokens",
      "url",
      "api_key"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;

    return attrs;
  }
}
