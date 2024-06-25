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
    let attrs = this.getProperties(CREATE_ATTRIBUTES);
    return AiTool.create(attrs);
  }
}
