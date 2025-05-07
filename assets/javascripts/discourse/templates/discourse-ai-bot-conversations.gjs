import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { i18n } from "discourse-i18n";
import AiPersonaLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-persona-llm-selector";

export default RouteTemplate(
  <template>
    <div class="ai-bot-conversations">
      <AiPersonaLlmSelector
        @showLabels={{true}}
        @setPersonaId={{@controller.setPersonaId}}
        @setTargetRecipient={{@controller.setTargetRecipient}}
      />

      <div class="ai-bot-conversations__content-wrapper">
        <div class="ai-bot-conversations__title">
          {{i18n "discourse_ai.ai_bot.conversations.header"}}
        </div>
        <PluginOutlet
          @name="ai-bot-conversations-above-input"
          @outletArgs={{hash
            updateInput=@controller.updateInputValue
            submit=@controller.prepareAndSubmitToBot
          }}
        />

        <div class="ai-bot-conversations__input-wrapper">
          <DButton
            @icon="upload"
            @action={{@controller.openFileUpload}}
            @title="discourse_ai.ai_bot.conversations.upload_files"
            class="btn btn-transparent ai-bot-upload-btn"
          />
          <textarea
            {{didInsert @controller.setTextArea}}
            {{on "input" @controller.updateInputValue}}
            {{on "keydown" @controller.handleKeyDown}}
            id="ai-bot-conversations-input"
            autofocus="true"
            placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
            minlength="10"
            disabled={{@controller.loading}}
            rows="1"
          />
          <DButton
            @action={{@controller.prepareAndSubmitToBot}}
            @icon="paper-plane"
            @isLoading={{@controller.loading}}
            @title="discourse_ai.ai_bot.conversations.header"
            class="ai-bot-button btn-transparent ai-conversation-submit"
          />
          <input
            type="file"
            id="ai-bot-file-uploader"
            class="hidden-upload-field"
            multiple="multiple"
            {{didInsert @controller.registerFileInput}}
          />
        </div>

        <p class="ai-disclaimer">
          {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
        </p>

        {{#if @controller.showUploadsContainer}}
          <div class="ai-bot-conversations__uploads-container">
            {{#each @controller.uploads as |upload|}}
              <div class="ai-bot-upload">
                <span class="ai-bot-upload__filename">
                  {{upload.original_filename}}
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn @controller.removeUpload upload}}
                  class="btn-transparent ai-bot-upload__remove"
                />
              </div>
            {{/each}}

            {{#each @controller.inProgressUploads as |upload|}}
              <div class="ai-bot-upload ai-bot-upload--in-progress">
                <span class="ai-bot-upload__filename">{{upload.fileName}}</span>
                <span class="ai-bot-upload__progress">
                  {{upload.progress}}%
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn @controller.cancelUpload upload}}
                  class="btn-flat ai-bot-upload__cancel"
                />
              </div>
            {{/each}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
);
