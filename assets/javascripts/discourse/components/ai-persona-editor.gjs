import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { inject as service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Avatar from "discourse/helpers/bound-avatar-template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import I18n from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";
import DTooltip from "float-kit/components/d-tooltip";
import AiCommandSelector from "./ai-command-selector";
import AiLlmSelector from "./ai-llm-selector";
import AiPersonaCommandOptions from "./ai-persona-command-options";
import PersonaRagUploader from "./persona-rag-uploader";

export default class PersonaEditor extends Component {
  @service router;
  @service store;
  @service dialog;
  @service toasts;
  @service siteSettings;

  @tracked allGroups = [];
  @tracked isSaving = false;
  @tracked editingModel = null;
  @tracked showDelete = false;
  @tracked maxPixelsValue = null;
  @tracked ragIndexingStatuses = null;

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.showDelete = !this.args.model.isNew && !this.args.model.system;
    this.maxPixelsValue = this.findClosestPixelValue(
      this.editingModel.vision_max_pixels
    );
  }

  findClosestPixelValue(pixels) {
    let value = "high";
    this.maxPixelValues.forEach((info) => {
      if (pixels === info.pixels) {
        value = info.id;
      }
    });
    return value;
  }

  @cached
  get maxPixelValues() {
    const l = (key) =>
      I18n.t(`discourse_ai.ai_persona.vision_max_pixel_sizes.${key}`);
    return [
      { id: "low", name: l("low"), pixels: 65536 },
      { id: "medium", name: l("medium"), pixels: 262144 },
      { id: "high", name: l("high"), pixels: 1048576 },
    ];
  }

  @action
  async updateAllGroups() {
    this.allGroups = await Group.findAll();
  }

  @action
  async save() {
    const isNew = this.args.model.isNew;
    this.isSaving = true;

    const backupModel = this.args.model.workingCopy();

    this.args.model.setProperties(this.editingModel);
    try {
      await this.args.model.save();
      this.#sortPersonas();
      if (isNew && this.args.model.rag_uploads.length === 0) {
        this.args.personas.addObject(this.args.model);
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai.ai-personas.show",
          this.args.model
        );
      } else {
        this.toasts.success({
          data: { message: I18n.t("discourse_ai.ai_persona.saved") },
          duration: 2000,
        });
      }
    } catch (e) {
      this.args.model.setProperties(backupModel);
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  get showTemperature() {
    return this.editingModel?.temperature || !this.editingModel?.system;
  }

  get showTopP() {
    return this.editingModel?.top_p || !this.editingModel?.system;
  }

  get adminUser() {
    return AdminUser.create(this.editingModel?.user);
  }

  get mappedDefaultLlm() {
    return this.editingModel?.default_llm || "blank";
  }

  set mappedDefaultLlm(value) {
    if (value === "blank") {
      this.editingModel.default_llm = null;
    } else {
      this.editingModel.default_llm = value;
    }
  }

  @action
  onChangeMaxPixels(value) {
    const entry = this.maxPixelValues.findBy("id", value);
    if (!entry) {
      return;
    }
    this.maxPixelsValue = value;
    this.editingModel.vision_max_pixels = entry.pixels;
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: I18n.t("discourse_ai.ai_persona.confirm_delete"),
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          this.args.personas.removeObject(this.args.model);
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai.ai-personas.index"
          );
        });
      },
    });
  }

  @action
  updateAllowedGroups(ids) {
    this.editingModel.set("allowed_group_ids", ids);
  }

  @action
  async toggleEnabled() {
    await this.toggleField("enabled");
  }

  @action
  async togglePriority() {
    await this.toggleField("priority", true);
  }

  @action
  async toggleMentionable() {
    await this.toggleField("mentionable");
  }

  @action
  async toggleVisionEnabled() {
    await this.toggleField("vision_enabled");
  }

  @action
  async createUser() {
    try {
      let user = await this.args.model.createUser();
      this.editingModel.set("user", user);
      this.editingModel.set("user_id", user.id);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  addUpload(upload) {
    const newUpload = upload;
    newUpload.status = "uploaded";
    newUpload.statusText = I18n.t("discourse_ai.ai_persona.uploads.uploaded");
    this.editingModel.rag_uploads.addObject(newUpload);
  }

  @action
  removeUpload(upload) {
    this.editingModel.rag_uploads.removeObject(upload);
    this.save();
  }

  async toggleField(field, sortPersonas) {
    this.args.model.set(field, !this.args.model[field]);
    this.editingModel.set(field, this.args.model[field]);
    if (!this.args.model.isNew) {
      try {
        const args = {};
        args[field] = this.args.model[field];

        await this.args.model.update(args);
        if (sortPersonas) {
          this.#sortPersonas();
        }
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  #sortPersonas() {
    const sorted = this.args.personas.toArray().sort((a, b) => {
      if (a.priority && !b.priority) {
        return -1;
      } else if (!a.priority && b.priority) {
        return 1;
      } else {
        return a.name.localeCompare(b.name);
      }
    });
    this.args.personas.clear();
    this.args.personas.setObjects(sorted);
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai.ai-personas"
      @label="discourse_ai.ai_persona.back"
    />
    <form
      class="form-horizontal ai-persona-editor"
      {{didUpdate this.updateModel @model.id}}
      {{didInsert this.updateModel @model.id}}
      {{didInsert this.updateAllGroups @model.id}}
    >
      <div class="control-group">
        <DToggleSwitch
          class="ai-persona-editor__enabled"
          @state={{@model.enabled}}
          @label="discourse_ai.ai_persona.enabled"
          {{on "click" this.toggleEnabled}}
        />
      </div>
      <div class="control-group ai-persona-editor__priority">
        <DToggleSwitch
          class="ai-persona-editor__priority"
          @state={{@model.priority}}
          @label="discourse_ai.ai_persona.priority"
          {{on "click" this.togglePriority}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.ai_persona.priority_help"}}
        />
      </div>
      {{#if this.editingModel.user}}
        <div class="control-group ai-persona-editor__mentionable">
          <DToggleSwitch
            class="ai-persona-editor__mentionable_toggle"
            @state={{@model.mentionable}}
            @label="discourse_ai.ai_persona.mentionable"
            {{on "click" this.toggleMentionable}}
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.ai_persona.mentionable_help"}}
          />
        </div>
      {{/if}}
      <div class="control-group ai-persona-editor__vision_enabled">
        <DToggleSwitch
          @state={{@model.vision_enabled}}
          @label="discourse_ai.ai_persona.vision_enabled"
          {{on "click" this.toggleVisionEnabled}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.ai_persona.vision_enabled_help"}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.name"}}</label>
        <Input
          class="ai-persona-editor__name"
          @type="text"
          @value={{this.editingModel.name}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.description"}}</label>
        <Textarea
          class="ai-persona-editor__description"
          @value={{this.editingModel.description}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.default_llm"}}</label>
        <AiLlmSelector
          class="ai-persona-editor__llms"
          @value={{this.mappedDefaultLlm}}
          @llms={{@personas.resultSetMeta.llms}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.ai_persona.default_llm_help"}}
        />
      </div>
      {{#unless @model.isNew}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.ai_persona.user"}}</label>
          {{#if this.editingModel.user}}
            <a
              class="avatar"
              href={{this.editingModel.user.path}}
              data-user-card={{this.editingModel.user.username}}
            >
              {{Avatar this.editingModel.user.avatar_template "small"}}
            </a>
            <LinkTo @route="adminUser" @model={{this.adminUser}}>
              {{this.editingModel.user.username}}
            </LinkTo>
          {{else}}
            <DButton
              @action={{this.createUser}}
              class="ai-persona-editor__create-user"
            >
              {{I18n.t "discourse_ai.ai_persona.create_user"}}
            </DButton>
            <DTooltip
              @icon="question-circle"
              @content={{I18n.t "discourse_ai.ai_persona.create_user_help"}}
            />
          {{/if}}
        </div>
      {{/unless}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.commands"}}</label>
        <AiCommandSelector
          class="ai-persona-editor__commands"
          @value={{this.editingModel.commands}}
          @disabled={{this.editingModel.system}}
          @commands={{@personas.resultSetMeta.commands}}
        />
      </div>
      {{#unless this.editingModel.system}}
        <AiPersonaCommandOptions
          @persona={{this.editingModel}}
          @commands={{this.editingModel.commands}}
          @allCommands={{@personas.resultSetMeta.commands}}
        />
      {{/unless}}
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.allowed_groups"}}</label>
        <GroupChooser
          @value={{this.editingModel.allowed_group_ids}}
          @content={{this.allGroups}}
          @onChange={{this.updateAllowedGroups}}
        />
      </div>
      <div class="control-group">
        <label for="ai-persona-editor__system_prompt">{{I18n.t
            "discourse_ai.ai_persona.system_prompt"
          }}</label>
        <Textarea
          class="ai-persona-editor__system_prompt"
          @value={{this.editingModel.system_prompt}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{I18n.t "discourse_ai.ai_persona.max_context_posts"}}</label>
        <Input
          @type="number"
          lang="en"
          class="ai-persona-editor__max_context_posts"
          @value={{this.editingModel.max_context_posts}}
        />
        <DTooltip
          @icon="question-circle"
          @content={{I18n.t "discourse_ai.ai_persona.max_context_posts_help"}}
        />
      </div>
      {{#if @model.vision_enabled}}
        <div class="control-group">
          <label>{{I18n.t "discourse_ai.ai_persona.vision_max_pixels"}}</label>
          <ComboBox
            @value={{this.maxPixelsValue}}
            @content={{this.maxPixelValues}}
            @onChange={{this.onChangeMaxPixels}}
          />
        </div>
      {{/if}}
      <div class="control-group">
        {{#if this.showTemperature}}
          <label>{{I18n.t "discourse_ai.ai_persona.temperature"}}</label>
          <Input
            @type="number"
            class="ai-persona-editor__temperature"
            step="any"
            lang="en"
            @value={{this.editingModel.temperature}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.ai_persona.temperature_help"}}
          />
        {{/if}}
        {{#if this.showTopP}}
          <label>{{I18n.t "discourse_ai.ai_persona.top_p"}}</label>
          <Input
            @type="number"
            step="any"
            lang="en"
            class="ai-persona-editor__top_p"
            @value={{this.editingModel.top_p}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="question-circle"
            @content={{I18n.t "discourse_ai.ai_persona.top_p_help"}}
          />
        {{/if}}
      </div>
      {{#if this.siteSettings.ai_embeddings_enabled}}
        <div class="control-group">
          <PersonaRagUploader
            @persona={{this.editingModel}}
            @ragUploads={{this.editingModel.rag_uploads}}
            @onAdd={{this.addUpload}}
            @onRemove={{this.removeUpload}}
          />
        </div>
      {{/if}}
      <div class="control-group ai-persona-editor__action_panel">
        <DButton
          class="btn-primary ai-persona-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >{{I18n.t "discourse_ai.ai_persona.save"}}</DButton>
        {{#if this.showDelete}}
          <DButton
            @action={{this.delete}}
            class="btn-danger ai-persona-editor__delete"
          >
            {{I18n.t "discourse_ai.ai_persona.delete"}}
          </DButton>
        {{/if}}
      </div>
    </form>
  </template>
}
