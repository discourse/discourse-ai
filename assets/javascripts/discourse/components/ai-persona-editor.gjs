import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { LinkTo } from "@ember/routing";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import Textarea from "discourse/components/d-textarea";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Avatar from "discourse/helpers/bound-avatar-template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";
import DTooltip from "float-kit/components/d-tooltip";
import AiForcedToolStrategySelector from "./ai-forced-tool-strategy-selector";
import AiLlmSelector from "./ai-llm-selector";
import AiPersonaToolOptions from "./ai-persona-tool-options";
import AiToolSelector from "./ai-tool-selector";
import RagOptions from "./rag-options";
import RagUploader from "./rag-uploader";

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

  @tracked selectedTools = [];
  @tracked selectedToolNames = [];
  @tracked forcedToolNames = [];
  @tracked hasDefaultLlm = false;

  get chatPluginEnabled() {
    return this.siteSettings.chat_enabled;
  }

  get allowForceTools() {
    return !this.editingModel?.system && this.selectedToolNames.length > 0;
  }

  get hasForcedTools() {
    return this.forcedToolNames.length > 0;
  }

  @action
  forcedToolsChanged(tools) {
    this.forcedToolNames = tools;
    this.editingModel.forcedTools = this.forcedToolNames;
  }

  @action
  toolsChanged(tools) {
    this.selectedTools = this.args.personas.resultSetMeta.tools.filter((tool) =>
      tools.includes(tool.id)
    );
    this.selectedToolNames = tools.slice();

    this.forcedToolNames = this.forcedToolNames.filter(
      (tool) => this.editingModel.tools.indexOf(tool) !== -1
    );

    this.editingModel.tools = this.selectedToolNames;
    this.editingModel.forcedTools = this.forcedToolNames;
  }

  @action
  updateModel() {
    this.editingModel = this.args.model.workingCopy();
    this.hasDefaultLlm = !!this.editingModel.default_llm;
    this.showDelete = !this.args.model.isNew && !this.args.model.system;
    this.maxPixelsValue = this.findClosestPixelValue(
      this.editingModel.vision_max_pixels
    );

    this.selectedToolNames = this.editingModel.tools || [];
    this.selectedTools = this.args.personas.resultSetMeta.tools.filter((tool) =>
      this.selectedToolNames.includes(tool.id)
    );
    this.forcedToolNames = this.editingModel.forcedTools || [];
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
      i18n(`discourse_ai.ai_persona.vision_max_pixel_sizes.${key}`);
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
          "adminPlugins.show.discourse-ai-personas.edit",
          this.args.model
        );
      } else {
        this.toasts.success({
          data: { message: i18n("discourse_ai.ai_persona.saved") },
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

  get mappedQuestionConsolidatorLlm() {
    return this.editingModel?.question_consolidator_llm_id ?? "blank";
  }

  set mappedQuestionConsolidatorLlm(value) {
    if (value === "blank") {
      this.editingModel.question_consolidator_llm_id = null;
    } else {
      this.editingModel.question_consolidator_llm_id = value;
    }
  }

  get mappedDefaultLlm() {
    return this.editingModel?.default_llm_id ?? "blank";
  }

  set mappedDefaultLlm(value) {
    if (value === "blank") {
      this.editingModel.default_llm_id = null;
      this.hasDefaultLlm = false;
    } else {
      this.editingModel.default_llm_id = value;
      this.hasDefaultLlm = true;
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
      message: i18n("discourse_ai.ai_persona.confirm_delete"),
      didConfirm: () => {
        return this.args.model.destroyRecord().then(() => {
          this.args.personas.removeObject(this.args.model);
          this.router.transitionTo(
            "adminPlugins.show.discourse-ai-personas.index"
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
  updateUploads(uploads) {
    this.editingModel.rag_uploads = uploads;
  }

  @action
  removeUpload(upload) {
    this.editingModel.rag_uploads.removeObject(upload);
    if (!this.args.model.isNew) {
      this.save();
    }
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
      @route="adminPlugins.show.discourse-ai-personas"
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
          @icon="circle-question"
          @content={{i18n "discourse_ai.ai_persona.priority_help"}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.ai_persona.name"}}</label>
        <Input
          class="ai-persona-editor__name"
          @type="text"
          @value={{this.editingModel.name}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group">
        <label>{{i18n "discourse_ai.ai_persona.description"}}</label>
        <Textarea
          class="ai-persona-editor__description"
          @value={{this.editingModel.description}}
          disabled={{this.editingModel.system}}
        />
      </div>
      {{#if this.editingModel.user}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.default_llm"}}</label>
          <AiLlmSelector
            class="ai-persona-editor__llms"
            @value={{this.mappedDefaultLlm}}
            @llms={{@personas.resultSetMeta.llms}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.ai_persona.default_llm_help"}}
          />
        </div>
        {{#if this.hasDefaultLlm}}
          <div class="control-group">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.editingModel.force_default_llm}}
              />
              {{i18n "discourse_ai.ai_persona.force_default_llm"}}</label>
          </div>
        {{/if}}
      {{/if}}
      {{#unless @model.isNew}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.user"}}</label>
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
              {{i18n "discourse_ai.ai_persona.create_user"}}
            </DButton>
            <DTooltip
              @icon="circle-question"
              @content={{i18n "discourse_ai.ai_persona.create_user_help"}}
            />
          {{/if}}
        </div>
      {{/unless}}
      <div class="control-group">
        <label>{{i18n "discourse_ai.ai_persona.tools"}}</label>
        <AiToolSelector
          class="ai-persona-editor__tools"
          @value={{this.selectedToolNames}}
          @disabled={{this.editingModel.system}}
          @tools={{@personas.resultSetMeta.tools}}
          @onChange={{this.toolsChanged}}
        />
      </div>
      {{#if this.allowForceTools}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.forced_tools"}}</label>
          <AiToolSelector
            class="ai-persona-editor__forced_tools"
            @value={{this.forcedToolNames}}
            @tools={{this.selectedTools}}
            @onChange={{this.forcedToolsChanged}}
          />
        </div>
        {{#if this.hasForcedTools}}
          <div class="control-group">
            <label>{{i18n
                "discourse_ai.ai_persona.forced_tool_strategy"
              }}</label>
            <AiForcedToolStrategySelector
              class="ai-persona-editor__forced_tool_strategy"
              @value={{this.editingModel.forced_tool_count}}
            />
          </div>
        {{/if}}
      {{/if}}
      <AiPersonaToolOptions
        @persona={{this.editingModel}}
        @tools={{this.selectedToolNames}}
        @llms={{@personas.resultSetMeta.llms}}
        @allTools={{@personas.resultSetMeta.tools}}
      />
      <div class="control-group">
        <label>{{i18n "discourse_ai.ai_persona.allowed_groups"}}</label>
        <GroupChooser
          @value={{this.editingModel.allowed_group_ids}}
          @content={{this.allGroups}}
          @onChange={{this.updateAllowedGroups}}
        />
      </div>
      <div class="control-group">
        <label for="ai-persona-editor__system_prompt">{{i18n
            "discourse_ai.ai_persona.system_prompt"
          }}</label>
        <Textarea
          class="ai-persona-editor__system_prompt"
          @value={{this.editingModel.system_prompt}}
          disabled={{this.editingModel.system}}
        />
      </div>
      <div class="control-group ai-persona-editor__allow_personal_messages">
        <label>
          <Input
            @type="checkbox"
            @checked={{this.editingModel.allow_personal_messages}}
          />
          {{i18n "discourse_ai.ai_persona.allow_personal_messages"}}</label>
        <DTooltip
          @icon="circle-question"
          @content={{i18n
            "discourse_ai.ai_persona.allow_personal_messages_help"
          }}
        />
      </div>
      {{#if this.editingModel.user}}
        <div class="control-group ai-persona-editor__allow_topic_mentions">
          <label>
            <Input
              @type="checkbox"
              @checked={{this.editingModel.allow_topic_mentions}}
            />
            {{i18n "discourse_ai.ai_persona.allow_topic_mentions"}}</label>
          <DTooltip
            @icon="circle-question"
            @content={{i18n
              "discourse_ai.ai_persona.allow_topic_mentions_help"
            }}
          />
        </div>
        {{#if this.chatPluginEnabled}}
          <div
            class="control-group ai-persona-editor__allow_chat_direct_messages"
          >
            <label>
              <Input
                @type="checkbox"
                @checked={{this.editingModel.allow_chat_direct_messages}}
              />
              {{i18n
                "discourse_ai.ai_persona.allow_chat_direct_messages"
              }}</label>
            <DTooltip
              @icon="circle-question"
              @content={{i18n
                "discourse_ai.ai_persona.allow_chat_direct_messages_help"
              }}
            />
          </div>
          <div
            class="control-group ai-persona-editor__allow_chat_channel_mentions"
          >
            <label>
              <Input
                @type="checkbox"
                @checked={{this.editingModel.allow_chat_channel_mentions}}
              />
              {{i18n
                "discourse_ai.ai_persona.allow_chat_channel_mentions"
              }}</label>
            <DTooltip
              @icon="circle-question"
              @content={{i18n
                "discourse_ai.ai_persona.allow_chat_channel_mentions_help"
              }}
            />
          </div>
        {{/if}}
      {{/if}}
      <div class="control-group ai-persona-editor__tool-details">
        <label>
          <Input @type="checkbox" @checked={{this.editingModel.tool_details}} />
          {{i18n "discourse_ai.ai_persona.tool_details"}}</label>
        <DTooltip
          @icon="circle-question"
          @content={{i18n "discourse_ai.ai_persona.tool_details_help"}}
        />
      </div>
      <div class="control-group ai-persona-editor__vision_enabled">
        <label>
          <Input
            @type="checkbox"
            @checked={{this.editingModel.vision_enabled}}
          />
          {{i18n "discourse_ai.ai_persona.vision_enabled"}}</label>
        <DTooltip
          @icon="circle-question"
          @content={{i18n "discourse_ai.ai_persona.vision_enabled_help"}}
        />
      </div>
      {{#if this.editingModel.vision_enabled}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.vision_max_pixels"}}</label>
          <ComboBox
            @value={{this.maxPixelsValue}}
            @content={{this.maxPixelValues}}
            @onChange={{this.onChangeMaxPixels}}
          />
        </div>
      {{/if}}
      <div class="control-group">
        <label>{{i18n "discourse_ai.ai_persona.max_context_posts"}}</label>
        <Input
          @type="number"
          lang="en"
          class="ai-persona-editor__max_context_posts"
          @value={{this.editingModel.max_context_posts}}
        />
        <DTooltip
          @icon="circle-question"
          @content={{i18n "discourse_ai.ai_persona.max_context_posts_help"}}
        />
      </div>
      {{#if this.showTemperature}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.temperature"}}</label>
          <Input
            @type="number"
            class="ai-persona-editor__temperature"
            step="any"
            lang="en"
            @value={{this.editingModel.temperature}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.ai_persona.temperature_help"}}
          />
        </div>
      {{/if}}
      {{#if this.showTopP}}
        <div class="control-group">
          <label>{{i18n "discourse_ai.ai_persona.top_p"}}</label>
          <Input
            @type="number"
            step="any"
            lang="en"
            class="ai-persona-editor__top_p"
            @value={{this.editingModel.top_p}}
            disabled={{this.editingModel.system}}
          />
          <DTooltip
            @icon="circle-question"
            @content={{i18n "discourse_ai.ai_persona.top_p_help"}}
          />
        </div>
      {{/if}}
      {{#if this.siteSettings.ai_embeddings_enabled}}
        <div class="control-group">
          <RagUploader
            @target={{this.editingModel}}
            @updateUploads={{this.updateUploads}}
            @onRemove={{this.removeUpload}}
            @allowPdfsAndImages={{@personas.resultSetMeta.settings.rag_pdf_images_enabled}}
          />
        </div>
        <RagOptions
          @model={{this.editingModel}}
          @llms={{@personas.resultSetMeta.llms}}
          @allowPdfsAndImages={{@personas.resultSetMeta.settings.rag_pdf_images_enabled}}
        >
          <div class="control-group">
            <label>{{i18n
                "discourse_ai.ai_persona.rag_conversation_chunks"
              }}</label>
            <Input
              @type="number"
              step="any"
              lang="en"
              class="ai-persona-editor__rag_conversation_chunks"
              @value={{this.editingModel.rag_conversation_chunks}}
            />
            <DTooltip
              @icon="circle-question"
              @content={{i18n
                "discourse_ai.ai_persona.rag_conversation_chunks_help"
              }}
            />
          </div>
          <div class="control-group">
            <label>{{i18n
                "discourse_ai.ai_persona.question_consolidator_llm"
              }}</label>
            <AiLlmSelector
              class="ai-persona-editor__llms"
              @value={{this.mappedQuestionConsolidatorLlm}}
              @llms={{@personas.resultSetMeta.llms}}
            />

            <DTooltip
              @icon="circle-question"
              @content={{i18n
                "discourse_ai.ai_persona.question_consolidator_llm_help"
              }}
            />
          </div>
        </RagOptions>
      {{/if}}
      <div class="control-group ai-persona-editor__action_panel">
        <DButton
          class="btn-primary ai-persona-editor__save"
          @action={{this.save}}
          @disabled={{this.isSaving}}
        >{{i18n "discourse_ai.ai_persona.save"}}</DButton>
        {{#if this.showDelete}}
          <DButton
            @action={{this.delete}}
            class="btn-danger ai-persona-editor__delete"
          >
            {{i18n "discourse_ai.ai_persona.delete"}}
          </DButton>
        {{/if}}
      </div>
    </form>
  </template>
}
