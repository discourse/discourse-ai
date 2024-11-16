import { withPluginApi } from "discourse/lib/plugin-api";
import AiArtifact from "../discourse/components/ai-artifact";

function initializeAiArtifacts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      [...element.querySelectorAll("div.ai-artifact")].forEach((artifactElement) => {
        const artifactId = artifactElement.getAttribute("data-ai-artifact-id");

         helper.renderGlimmer(artifactElement, <template>
            <AiArtifact @artifactId={{artifactId}} />
          </template>);
      });
    },
    {
      id: "ai-artifact",
      onlyStream: true,
    }
  );
}

export default {
  name: "ai-artifact",
  initialize() {
    withPluginApi("0.8.7", initializeAiArtifacts);
  },
};
