import { ajax } from "discourse/lib/ajax";
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
      "api_key",
      "enabled_chat_bot"
    );
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;

    return attrs;
  }

  async testConfig() {
    return await ajax(`/admin/plugins/discourse-ai/ai-llms/test.json`, {
      data: { ai_llm: this.createProperties() },
    });
  }
}
