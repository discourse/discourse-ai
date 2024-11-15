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
                name: "html_body",
                description: "The HTML content for the BODY tag (do not include the BODY tag)",
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

        def self.allow_partial_tool_calls?
          true
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

          iframe =
            "<iframe src=\"#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{artifact.id}\" width=\"100%\" height=\"500\" frameborder=\"0\"></iframe>" if artifact

          content = []

          content << [:html, "### HTML\n\n```html\n#{html}\n```"] if html.present?

          content << [:css, "### CSS\n\n```css\n#{css}\n```"] if css.present?

          content << [:js, "### JavaScript\n\n```javascript\n#{js}\n```"] if js.present?

          content << [:preview, "### Preview\n\n#{iframe}"] if iframe

          content.sort_by! { |c| c[0] === @selected_tab ? 0 : 1 } if !artifact

          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
        end

        def update_custom_html_old(artifact = nil)
          html = parameters[:html_body].to_s
          css = parameters[:css].to_s
          js = parameters[:js].to_s

          tabs = { css: [css, "CSS"], js: [js, "JavaScript"], html: [html, "HTML"] }

          if artifact
            iframe =
              "<iframe src=\"#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{artifact.id}\" width=\"100%\" height=\"500\" frameborder=\"0\"></iframe>"
            tabs[:preview] = [iframe, "Preview"]
          end

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
              selected = " data-selected" if (first || (!artifact && tab == @selected_tab))
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
        end

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
