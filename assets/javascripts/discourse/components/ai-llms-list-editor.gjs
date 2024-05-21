import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AiLlmEditor from "./ai-llm-editor";

export default class AiLlmsListEditor extends Component {
  get hasNoLLMElements() {
    this.args.llms.length !== 0;
  }

  <template>
    <DBreadcrumbsItem as |linkClass|>
      <LinkTo
        @route="adminPlugins.show.discourse-ai-personas"
        class={{linkClass}}
      >
        {{i18n "discourse_ai.llms.short_title"}}
      </LinkTo>
    </DBreadcrumbsItem>

    <section class="ai-llms-list-editor admin-detail pull-left">

      <div class="ai-llms-list-editor__header">
        <h3>{{i18n "discourse_ai.llms.short_title"}}</h3>
        {{#unless @currentLlm.isNew}}
          <LinkTo
            @route="adminPlugins.show.discourse-ai-llms.new"
            class="btn btn-small btn-primary"
          >
            {{icon "plus"}}
            <span>{{I18n.t "discourse_ai.llms.new"}}</span>
          </LinkTo>
        {{/unless}}
      </div>

      <div class="ai-llms-list-editor__container">
        {{#if this.hasNoLLMElements}}
          <div class="ai-llms-list-editor__empty_list">
            {{icon "robot"}}
            {{i18n "discourse_ai.llms.no_llms"}}
          </div>
        {{else}}
          <div class="content-list ai-llms-list-editor__content_list">
            <ul>
              {{#each @llms as |llm|}}
                <li>
                  <LinkTo
                    @route="adminPlugins.show.discourse-ai-llms.show"
                    current-when="true"
                    @model={{llm}}
                  >
                    {{llm.display_name}}
                  </LinkTo>
                </li>
              {{/each}}
            </ul>
          </div>
        {{/if}}

        <div class="ai-llms-list-editor__current">
          {{#if @currentLlm}}
            <AiLlmEditor @model={{@currentLlm}} @llms={{@llms}} />
          {{/if}}
        </div>
      </div>
    </section>
  </template>
}
