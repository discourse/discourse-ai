import Component from "@glimmer/component";
import AiSemanticSearch from "../../components/ai-full-page-search";

export default class AiFullPageSearchConnector extends Component {
  static shouldRender(_args, { siteSettings }) {
    return siteSettings.ai_embeddings_semantic_search_enabled;
  }

  <template>
    <AiSemanticSearch
      @sortOrder={{@outletArgs.sortOrder}}
      @searchTerm={{@outletArgs.search}}
      @searchType={{@outletArgs.type}}
      @addSearchResults={{@outletArgs.addSearchResults}}
    />
  </template>
}
