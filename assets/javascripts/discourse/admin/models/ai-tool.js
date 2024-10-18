import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "description",
  "parameters",
  "script",
  "summary",
  "rag_uploads",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "enabled",
];

export default class AiTool extends RestModel {
  static checkName(name) {
    return ajax("/admin/plugins/discourse-ai/ai-tools/check-name", {
      data: { tool_name: name },
    });
  }
  createProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  updateProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  trackParameters(parameters) {
    return new TrackedArray(
      parameters?.map((p) => {
        const parameter = new TrackedObject(p);

        if (parameter.enum && parameter.enum.length) {
          parameter.enum = new TrackedArray(parameter.enum);
        } else {
          parameter.enum = null;
        }

        return parameter;
      })
    );
  }

  workingCopy() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);
    attrs.parameters = this.trackParameters(attrs.parameters);
    return this.store.createRecord("ai-tool", attrs);
  }
}
