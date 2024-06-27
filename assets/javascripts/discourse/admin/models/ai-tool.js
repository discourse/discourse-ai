import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "description",
  "parameters",
  "script",
  "summary",
  "enabled",
];

export default class AiTool extends RestModel {
  createProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  updateProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  workingCopy() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);

    attrs.parameters = new TrackedArray(
      attrs.parameters?.map((p) => {
        const parameter = new TrackedObject(p);

        if (parameter.enum_values) {
          parameter.enumValues = new TrackedArray(parameter.enum_values);
          delete parameter.enum_values;
        }

        return parameter;
      })
    );

    return this.store.createRecord("ai-tool", attrs);
  }
}
