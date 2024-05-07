import RestModel from "discourse/models/rest";

export default class AiLlm extends RestModel {
  createProperties() {
    return this.getProperties(
      "display_name",
      "name",
      "provider",
      "tokenizer",
      "max_prompt_tokens"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;

    return attrs;
  }
}
