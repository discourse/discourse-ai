import RouteTemplate from "ember-route-template";
import AiFeatureEditor from "discourse/plugins/discourse-ai/discourse/components/ai-feature-editor";

export default RouteTemplate(
  <template><AiFeatureEditor @model={{@model}} /></template>
);
