# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class CreateArtifact < Tool
        def self.name
          "create_artifact"
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
                name: "html_content",
                description: "The HTML content for the artifact",
                type: "string",
                required: true,
              },
              { name: "css", description: "Optional CSS styles for the artifact", type: "string" },
              {
                name: "js",
                description:
                  "Optional
              JavaScript code for the artifact",
                type: "string",
              },
            ],
          }
        end

        def invoke
          # Get the current post from context
          post = Post.find_by(id: context[:post_id])
          return error_response("No post context found") unless post

          html = parameters[:html_content].to_s
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
            tabs = {
              css: [css, "CSS"],
              js: [js, "JavaScript"],
              html: [html, "HTML"],
              preview: [
                "<iframe src=\"#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{artifact.id}\" width=\"100%\" height=\"500\" frameborder=\"0\"></iframe>",
                "Preview",
              ],
            }

            first = true
            html_tabs =
              tabs.map do |tab, (content, name)|
                selected = " data-selected" if first
                first = false
                (<<~HTML).strip
                <div class="ai-artifact-tab" data-#{tab}#{selected}>
                  <a>#{name}</a>
                </div>
              HTML
              end

            first = true
            html_panels =
              tabs.map do |tab, (content, name)|
                selected = " data-selected" if first
                first = false
                inner_content =
                if tab == :preview
                  content
                else
                  <<~HTML

                  ```#{tab}
                  #{content}
                  ```
                  HTML
                end
                (<<~HTML).strip
                <div class="ai-artifact-panel" data-#{tab}#{selected}>

                  #{inner_content}
                </div>
              HTML
              end

            self.custom_raw = <<~RAW
              <div class="ai-artifact">
                <div class="ai-artifact-tabs">
                  #{html_tabs.join("\n")}
                </div>
                <div class="ai-artifact-panels">
                  #{html_panels.join("\n")}
                </div>
              </div>
            RAW

            success_response(artifact)
          else
            error_response(artifact.errors.full_messages.join(", "))
          end
        end

        def chain_next_response?
          @chain_next_response
        end

        private

        def success_response(artifact)
          @chain_next_response = false
          iframe_url = "#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{artifact.id}"

          {
            status: "success",
            artifact_id: artifact.id,
            iframe_html:
              "<iframe src=\"#{iframe_url}\" width=\"100%\" height=\"500\" frameborder=\"0\"></iframe>",
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
