import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { clipboardCopy, escapeExpression } from "discourse/lib/utilities";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";

export default class DebugAiModal extends Component {
  @tracked info = null;
  @tracked justCopiedText = "";
  @tracked activeTab = "request";

  constructor() {
    super(...arguments);
    next(() => {
      this.loadApiRequestInfo();
    });
  }

  get htmlContext() {
    if (!this.info) {
      return "";
    }

    let parsed;

    try {
      if (this.activeTab === "request") {
        parsed = JSON.parse(this.info.raw_request_payload);
      } else {
        return this.formattedResponse(this.info.raw_response_payload);
      }
    } catch (e) {
      return this.info.raw_request_payload;
    }

    return htmlSafe(this.jsonToHtml(parsed));
  }

  formattedResponse(response) {
    // we need to replace the new lines with <br> to make it look good
    const split = response.split("\n");
    const safe = split.map((line) => escapeExpression(line)).join("<br>");

    return htmlSafe(safe);
  }

  jsonToHtml(json) {
    let html = "<ul>";
    for (let key in json) {
      if (!json.hasOwnProperty(key)) {
        continue;
      }
      html += "<li>";
      if (typeof json[key] === "object" && Array.isArray(json[key])) {
        html += `<strong>${escapeExpression(key)}:</strong> ${this.jsonToHtml(
          json[key]
        )}`;
      } else if (typeof json[key] === "object") {
        html += `<strong>${escapeExpression(
          key
        )}:</strong> <ul><li>${this.jsonToHtml(json[key])}</li></ul>`;
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
    return html;
  }

  @action
  copyRequest() {
    this.copy(this.info.raw_request_payload);
  }

  @action
  copyResponse() {
    this.copy(this.info.raw_response_payload);
  }

  copy(text) {
    clipboardCopy(text);
    this.justCopiedText = I18n.t("discourse_ai.ai_bot.conversation_shared");

    discourseLater(() => {
      this.justCopiedText = "";
    }, 2000);
  }

  loadApiRequestInfo() {
    ajax(
      `/discourse-ai/ai-bot/post/${this.args.model.id}/show-debug-info.json`
    ).then((result) => {
      this.info = result;
    });
  }

  get requestActive() {
    return this.activeTab === "request" ? "active" : "";
  }

  get responseActive() {
    return this.activeTab === "response" ? "active" : "";
  }

  @action
  requestClicked(e) {
    this.activeTab = "request";
    e.preventDefault();
  }

  @action
  responseClicked(e) {
    this.activeTab = "response";
    e.preventDefault();
  }

  <template>
    <DModal
      class="ai-debug-modal"
      @title={{i18n "discourse_ai.ai_bot.debug_ai_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <ul class="nav nav-pills ai-debug-modal__nav">
          <li><a
              href=""
              class={{this.requestActive}}
              {{on "click" this.requestClicked}}
            >{{i18n "discourse_ai.ai_bot.debug_ai_modal.request"}}</a></li>
          <li><a
              href=""
              class={{this.responseActive}}
              {{on "click" this.responseClicked}}
            >{{i18n "discourse_ai.ai_bot.debug_ai_modal.response"}}</a></li>
        </ul>
        <div class="ai-debug-modal__tokens">
          <span>
            {{i18n "discourse_ai.ai_bot.debug_ai_modal.request_tokens"}}
            {{this.info.request_tokens}}
          </span>
          <span>
            {{i18n "discourse_ai.ai_bot.debug_ai_modal.response_tokens"}}
            {{this.info.response_tokens}}
          </span>
        </div>
        <div class="debug-ai-modal__preview">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn confirm"
          @icon="copy"
          @action={{this.copyRequest}}
          @label="discourse_ai.ai_bot.debug_ai_modal.copy_request"
        />
        <DButton
          class="btn confirm"
          @icon="copy"
          @action={{this.copyResponse}}
          @label="discourse_ai.ai_bot.debug_ai_modal.copy_response"
        />
        <span class="ai-debut-modal__just-copied">{{this.justCopiedText}}</span>
      </:footer>
    </DModal>
  </template>
}
