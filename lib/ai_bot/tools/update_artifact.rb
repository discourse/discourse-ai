# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class UpdateArtifact < Tool
        def self.name
          "update_artifact"
        end

        # this is not working that well, we support it, but I am leaving it dormant for now
        def self.unified_diff_tip
          <<~TIP
            When updating and artifact in diff mode unified diffs can be applied:

            If editing:

            <div>
              <p>Some text</p>
            </div>

            You can provide a diff like:

            <div>
            - <p>Some text</p>
            + <p>Some new text</p>
            </div>

            This will result in:

            <div>
              <p>Some new text</p>
            </div>

            If you need to supply multiple hunks for a diff use a @@ separator, for example:

            @@ -1,3 +1,3 @@
            - <p>Some text</p>
            + <p>Some new text</p>
            @@ -5,3 +5,3 @@
            - </div>
            + <p>more text</p>
            </div>

            If you supply text without @@ seperators or + and - prefixes, the entire text will be appended to the artifact section.

          TIP
        end

        def self.signature
          {
            name: "update_artifact",
            description:
            "Updates an existing web artifact with new HTML, CSS, or JavaScript content. Note either html, css, or js MUST be provided. You may provide all three if desired.",
            parameters: [
              {
                name: "artifact_id",
                description: "The ID of the artifact to update",
                type: "integer",
                required: true,
              },
              { name: "html", description: "new HTML content for the artifact", type: "string" },
              { name: "css", description: "new CSS content for the artifact", type: "string" },
              {
                name: "js",
                description: "new JavaScript content for the artifact",
                type: "string",
              },
              {
                name: "change_description",
                description:
                  "A brief description of the changes being made. Note: This only documents the change - you must provide the actual content in html/css/js parameters to make changes.",
                type: "string",
              },
            ],
          }
        end

        def self.allow_partial_tool_calls?
          true
        end

        def chain_next_response?
          @chain_next_response
        end

        def partial_invoke
          @selected_tab = :html
          if @prev_parameters
            @selected_tab = parameters.keys.find { |k| @prev_parameters[k] != parameters[k] }
          end
          update_custom_html
          @prev_parameters = parameters.dup
        end

        def invoke
          yield "Updating Artifact"

          post = Post.find_by(id: context[:post_id])
          return error_response("No post context found") unless post

          artifact = AiArtifact.find_by(id: parameters[:artifact_id])
          return error_response("Artifact not found") unless artifact

          if artifact.post.topic.id != post.topic.id
            return error_response("Attempting to update an artifact you are not allowed to")
          end

          last_version = artifact.versions.order(version_number: :desc).first

          begin
            version =
              artifact.create_new_version(
                html: parameters[:html] || last_version&.html || artifact.html,
                css: parameters[:css] || last_version&.css || artifact.css,
                js: parameters[:js] || last_version&.js || artifact.js,
                change_description: parameters[:change_description].to_s,
              )

            update_custom_html(artifact, version)
            success_response(artifact, version)
          rescue DiscourseAi::Utils::DiffUtils::DiffError => e
            error_response(e.to_llm_message)
          rescue => e
            error_response(e.message)
          end
        end

        private

        def update_custom_html(artifact = nil, version = nil)
          content = []

          if parameters[:html].present?
            content << [:html, "### HTML Changes\n\n```html\n#{parameters[:html]}\n```"]
          end

          if parameters[:css].present?
            content << [:css, "### CSS Changes\n\n```css\n#{parameters[:css]}\n```"]
          end

          if parameters[:js].present?
            content << [:js, "### JavaScript Changes\n\n```javascript\n#{parameters[:js]}\n```"]
          end

          if parameters[:change_description].present?
            content.unshift(
              [:description, "### Change Description\n\n#{parameters[:change_description]}"],
            )
          end

          content.sort_by! { |c| c[0] === @selected_tab ? 1 : 0 } if !artifact

          if artifact
            content.unshift([nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_changes")}']"])
            content << [nil, "[/details]"]
            content << [
              :preview,
              "### Preview\n\n<div class=\"ai-artifact\" data-ai-artifact-version=\"#{version.version_number}\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
            ]
          end

          content.unshift("\n\n")

          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
        end

        def success_response(artifact, version)
          @chain_next_response = false

          hash = {
            status: "success",
            artifact_id: artifact.id,
            version: version.version_number,
            message: "Artifact updated successfully and rendered to user.",
          }

          hash
        end

        def error_response(message)
          @chain_next_response = true
          self.custom_raw = ""

          { status: "error", error: message }
        end

        def help
          "Updates an existing web artifact with changes to its HTML, CSS, or JavaScript content. " \
            "Requires the artifact ID and at least one change diff. " \
            "Changes are applied using unified diff format. " \
            "A description of the changes is required for version history."
        end
      end
    end
  end
end
