import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

const AiGistDisclosure = <template>
  <span class="ai-topic-gist__disclosure">
    {{icon "discourse-sparkles"}}
    {{i18n "discourse_ai.summarization.disclosure"}}
  </span>
</template>;

export default AiGistDisclosure;
