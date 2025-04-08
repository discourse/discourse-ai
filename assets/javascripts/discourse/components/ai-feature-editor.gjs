import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import SiteSettingComponent from "admin/components/site-setting";

export default class AiFeatureEditor extends Component {
  @service toasts;
  @service currentUser;
  @service router;

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-features"
      @label="discourse_ai.features.back"
    />
    <section class="ai-feature-editor__header">
      <h2>{{@model.name}}</h2>
      <p>{{@model.description}}</p>
    </section>

    <section class="ai-feature-editor">
      {{#each @model.feature_settings as |setting|}}
        <div>
          <SiteSettingComponent @setting={{setting}} />
        </div>
      {{/each}}
    </section>
  </template>
}
