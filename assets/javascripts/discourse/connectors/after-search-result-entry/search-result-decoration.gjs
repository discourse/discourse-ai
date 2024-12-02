import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

function addResultClass(element) {
  element.closest(".fps-result")?.classList.add("ai-result");
}

const SearchResultDecoration = <template>
  <div
    class="ai-result__icon"
    title={{i18n "discourse_ai.embeddings.ai_generated_result"}}
    {{didInsert addResultClass}}
  >
    {{icon "discourse-sparkles"}}
  </div>
</template>;

export default SearchResultDecoration;
