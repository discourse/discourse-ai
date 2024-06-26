import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export const IMAGE_MARKDOWN_REGEX =
  /!\[(.*?)\|(\d{1,4}x\d{1,4})(,\s*\d{1,3}%)?(.*?)\]\((upload:\/\/.*?)\)(?!(.*`))/g;

export function jsonToHtml(json) {
  if (typeof json !== "object") {
    return escapeExpression(json);
  }
  let html = "<ul>";
  for (let key in json) {
    if (!json.hasOwnProperty(key)) {
      continue;
    }
    html += "<li>";
    if (typeof json[key] === "object" && Array.isArray(json[key])) {
      html += `<strong>${escapeExpression(key)}:</strong> ${jsonToHtml(
        json[key]
      )}`;
    } else if (typeof json[key] === "object") {
      html += `<strong>${escapeExpression(key)}:</strong> <ul><li>${jsonToHtml(
        json[key]
      )}</li></ul>`;
    } else {
      let value = json[key];
      if (typeof value === "string") {
        value = escapeExpression(value);
        value = value.replace(/\n/g, "<br>");
      }
      html += `<strong>${escapeExpression(key)}:</strong> ${value}`;
    }
    html += "</li>";
  }
  html += "</ul>";
  return htmlSafe(html);
}
