import Component from '@glimmer/component';
import icon from "discourse-common/helpers/d-icon";

export default class SearchResultDecoration extends Component {
  <template>
    <div class="ai-result__icon">
      {{icon "discourse-sparkles"}}
    </div>
  </template>
}