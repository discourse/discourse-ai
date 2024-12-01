# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class CreateArtifact < Tool
        def self.name
          "create_artifact"
        end

        def self.js_dependency_tip
          <<~TIP
            If you need to include a JavaScript library, you may include assets from:
            - unpkg.com
            - cdnjs.com
            - jsdelivr.com
            - ajax.googleapis.com

            To include them ensure they are the last tag in your HTML body.
            Example: <script crossorigin src="https://cdn.jsdelivr.net/npm/vue@2.6.14/dist/vue.min.js"></script>
          TIP
        end

        def self.js_script_tag_tip
          <<~TIP
            if you need a custom script tag, you can use the following format:

            <script type="module">
              // your script here
            </script>

            If you only need a regular script tag, you can use the following format:

            // your script here
          TIP
        end

        def self.signature
          {
            name: "create_artifact",
            description:
              "Creates a web artifact with HTML, CSS, and JavaScript that can be displayed in an iframe",
            parameters: [
              {
                name: "name",
                description: "A name for the artifact (max 255 chars)",
                type: "string",
                required: true,
              },
              {
                name: "html_body",
                description: "The HTML content for the BODY tag (do not include the BODY tag). #{js_dependency_tip}",
                type: "string",
                required: true,
              },
              { name: "css", description: "Optional CSS styles for the artifact", type: "string" },
              {
                name: "js",
                description:
                  "Optional
              JavaScript code for the artifact, this will be the last <script> tag in the BODY. #{js_script_tag_tip}",
                type: "string",
              },
            ],
          }
        end

        def self.allow_partial_tool_calls?
          true
        end

        def partial_invoke
          @selected_tab = :html_body
          if @prev_parameters
            @selected_tab = parameters.keys.find { |k| @prev_parameters[k] != parameters[k] }
          end
          update_custom_html
          @prev_parameters = parameters.dup
        end

        def invoke
          yield parameters[:name] || "Web Artifact"
          # Get the current post from context
          post = Post.find_by(id: context[:post_id])
          return error_response("No post context found") unless post

          html = parameters[:html_body].to_s
          css = parameters[:css].to_s
          js = parameters[:js].to_s

          # Create the artifact
          artifact =
            AiArtifact.new(
              user_id: bot_user.id,
              post_id: post.id,
              name: parameters[:name].to_s[0...255],
              html: html,
              css: css,
              js: js,
              metadata: parameters[:metadata],
            )

          if artifact.save
            update_custom_html(artifact)
            success_response(artifact)
          else
            error_response(artifact.errors.full_messages.join(", "))
          end
        end

        def chain_next_response?
          @chain_next_response
        end

        private

        def update_custom_html(artifact = nil)
          html = parameters[:html_body].to_s
          css = parameters[:css].to_s
          js = parameters[:js].to_s

          artifact_div =
            "<div class=\"ai-artifact\" data-ai-artifact-id=\"#{artifact.id}\"></div>" if artifact

          content = []

          content << [:html_body, "### HTML\n\n```html\n#{html}\n```"] if html.present?

          content << [:css, "### CSS\n\n```css\n#{css}\n```"] if css.present?

          content << [:js, "### JavaScript\n\n```javascript\n#{js}\n```"] if js.present?

          content.sort_by! { |c| c[0] === @selected_tab ? 1 : 0 } if !artifact

          if artifact
            content.unshift([nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_source")}']"])
            content << [nil, "[/details]"]
          end

          content << [:preview, "### Preview\n\n#{artifact_div}"] if artifact_div
          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
        end

        def success_response(artifact)
          @chain_next_response = false

          {
            status: "success",
            artifact_id: artifact.id,
            message: "Artifact created successfully and rendered to user.",
          }
        end

        def error_response(message)
          @chain_next_response = false

          { status: "error", error: message }
        end

        def help
          "Creates a web artifact with HTML, CSS, and JavaScript that can be displayed in an iframe. " \
            "Requires a name and HTML content. CSS and JavaScript are optional. " \
            "The artifact will be associated with the current post and can be displayed using an iframe."
        end
      end
    end
  end
end
