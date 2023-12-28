import { ajax } from "discourse/lib/ajax";
import { clipboardCopy } from "discourse/lib/utilities";
import I18n from "discourse-i18n";

export default async function (topic, fromPostNumber, toPostNumber) {
  const stream = topic.get("postStream");

  let postNumbers = [];
  // simpler to understand than Array.from
  for (let i = fromPostNumber; i <= toPostNumber; i++) {
    postNumbers.push(i);
  }

  const postIds = postNumbers.map((postNumber) => {
    return stream.findPostIdForPostNumber(postNumber);
  });

  // we need raw to construct so post stream will not help

  const url = `/t/${topic.id}/posts.json`;
  const data = {
    post_ids: postIds,
    include_raw: true,
  };

  const response = await ajax(url, { data });

  let formatted = [];
  formatted.push("<details class='ai-quote'>");
  formatted.push("<summary>");
  formatted.push(`<span>${topic.title}</span>`);
  formatted.push(
    `<span title='${I18n.t("discourse_ai.ai_bot.ai_title")}'>${I18n.t(
      "discourse_ai.ai_bot.ai_label"
    )}</span>`
  );
  formatted.push("</summary>");
  formatted.push("");

  response.post_stream.posts.forEach((post) => {
    formatted.push("");
    formatted.push(`**${post.username}:**`);
    formatted.push("");
    formatted.push(post.raw);
  });

  formatted.push("</details>");

  await clipboardCopy(formatted.join("\n"));
}
