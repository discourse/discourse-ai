import Component from "@glimmer/component";
import AIFullPageSemanticSearch from "discourse/plugins/discourse-ai/discourse/components/ai-full-page-semantic-search";

export default class SemanticSearch extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  <template>
    <AIFullPageSemanticSearch @outletArgs={{@outletArgs}} />
  </template>
}
