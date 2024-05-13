import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import DTooltip from "float-kit/components/d-tooltip";

export default class AiLlmEditor extends Component {
  @service toasts;
  @service router;

  @tracked isSaving = false;

  get selectedProviders() {
    const t = (provName) => {
      return I18n.t(`discourse_ai.llms.providers.${provName}`);
    };

    return this.args.llms.resultSetMeta.providers.map((prov) => {
      return { id: prov, name: t(prov) };
    });
  }

  @action
  async save() {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    try {
      await this.args.model.save();

      if (isNew) {
        this.args.llms.addObject(this.args.model);
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-llms.show",
          this.args.model
        );
      } else {
        this.toasts.success({
          data: { message: I18n.t("discourse_ai.llms.saved") },
          duration: 2000,
        });
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  <template>
    <form class="form-horizontal ai-llm-editor">
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.display_name"}}</label>
        <Input
          class="ai-llm-editor__display-name"
          @type="text"
          @value={{@model.display_name}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.name"}}</label>
        <Input
          class="ai-llm-editor__name"
          @type="text"
          @value={{@model.name}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.llms.hints.name"}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.llms.provider"}}</label>
        <ComboBox
          @value={{@model.provider}}
          @content={{this.selectedProviders}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.llms.tokenizer"}}</label>
        <ComboBox
          @value={{@model.tokenizer}}
          @content={{@llms.resultSetMeta.tokenizers}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.llms.max_prompt_tokens"}}</label>
        <Input
          @type="number"
          class="ai-llm-editor__max-prompt-tokens"
          step="any"
          min="0"
          lang="en"
          @value={{@model.max_prompt_tokens}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.llms.hints.max_prompt_tokens"}}
        />
      </div>

      <div class="control-group ai-llm-editor__action_panel">
        <DButton
          class="btn-primary ai-llm-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >
          {{I18n.t "discourse_ai.llms.save"}}
        </DButton>
      </div>
    </form>
  </template>
}
