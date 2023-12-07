import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class AiHelperLoading extends Component {
  <template>
    <div class="ai-helper-context-menu__loading">
      <div class="dot-falling"></div>
      <span>
        {{i18n "discourse_ai.ai_helper.context_menu.loading"}}
      </span>
      <DButton
        @icon="times"
        @title="discourse_ai.ai_helper.context_menu.cancel"
        @action={{@cancel}}
        class="btn-flat cancel-request"
      />
    </div>
  </template>
}
