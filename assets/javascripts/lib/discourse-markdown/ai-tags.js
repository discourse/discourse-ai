export function setup(helper) {
  helper.allowList(["details[class=ai-quote]"]);
  helper.allowList(["div[class=ai-artifact]", "div[data-ai-artifact-id]"]);
}
