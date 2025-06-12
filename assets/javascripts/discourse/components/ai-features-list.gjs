import { concat } from "@ember/helper";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

const AiFeaturesList = <template>
  <div class="ai-features-list">
    {{#each @modules as |module|}}
      <div class="ai-module" data-module-name={{module.module_name}}>
        <div class="ai-module__header">
          <div class="ai-module__module-title">
            <h3>{{i18n
                (concat "discourse_ai.features." module.module_name ".name")
              }}</h3>
            <DButton
              class="edit"
              @label="discourse_ai.features.edit"
              @route="adminPlugins.show.discourse-ai-features.edit"
              @routeModels={{module.id}}
            />
          </div>
          <div>{{i18n
              (concat
                "discourse_ai.features." module.module_name ".description"
              )
            }}</div>
        </div>

        <div class="admin-section-landing-wrapper ai-feature-cards">
          {{#each module.features as |feature|}}
            <div
              class="admin-section-landing-item ai-feature-card"
              data-feature-name={{feature.name}}
            >
              <div class="admin-section-landing-item__content">
                <div class="ai-feature-card__feature-name">
                  {{i18n
                    (concat
                      "discourse_ai.features."
                      module.module_name
                      "."
                      feature.name
                    )
                  }}
                  {{#unless feature.enabled}}
                    <span>{{i18n "discourse_ai.features.disabled"}}</span>
                  {{/unless}}
                </div>
                <div class="ai-feature-card__persona">
                  <span>{{i18n "discourse_ai.features.persona"}}</span>
                  {{#if feature.persona}}
                    <DButton
                      class="btn-flat btn-small ai-feature-card__persona-button"
                      @translatedLabel={{feature.persona.name}}
                      @route="adminPlugins.show.discourse-ai-personas.edit"
                      @routeModels={{feature.persona.id}}
                    />
                  {{else}}
                    {{i18n "discourse_ai.features.no_persona"}}
                  {{/if}}
                </div>
                {{#if feature.persona}}
                  <div class="ai-feature-card__groups">
                    <span>{{i18n "discourse_ai.features.groups"}}</span>
                    {{#if (gt feature.persona.allowed_groups.length 0)}}
                      <ul class="ai-feature-card__item-groups">
                        {{#each feature.persona.allowed_groups as |group|}}
                          <li>{{group.name}}</li>
                        {{/each}}
                      </ul>
                    {{else}}
                      {{i18n "discourse_ai.features.no_groups"}}
                    {{/if}}
                  </div>
                {{/if}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    {{/each}}
  </div>
</template>;

export default AiFeaturesList;
