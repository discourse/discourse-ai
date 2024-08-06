import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const AiHelperButtonGroup = <template>
  <ul class="ai-helper-button-group" ...attributes>
    {{#each @buttons as |button|}}
      <li>
        <DButton
          @icon={{button.icon}}
          @label={{button.label}}
          @action={{button.action}}
          class={{concatClass "btn-flat" button.classes}}
        />
      </li>
    {{/each}}
  </ul>
</template>;

export default AiHelperButtonGroup;
