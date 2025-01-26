# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class UpdateArtifact < Tool
        def self.name
          "update_artifact"
        end

        def self.diff_examples
          <<~EXAMPLES
            Example 1 - Adding a new button:
            Original HTML:
            <div class="calculator">
              <div class="display">0</div>
              <button>1</button>
            </div>

            Diff to add a new button:
              <button>1</button>
            + <button>2</button>

            Example 2 - Modifying styles:
            Original CSS:
            .button {
              background: blue;
              color: white;
            }

            Diff to change colors:
            .button {
            - background: blue;
            - color: white;
            + background: #333;
            + color: #fff;

            Example 3 - Updating JavaScript:
            Original JavaScript:
            function ignore() {
              // some function that is not part of diff
            }
            function calculate() {
              return a + b;
            }

            Diff to add multiplication:
            function calculate() {
            - return a + b;
            + return operation === 'multiply' ? a * b : a + b;
            }
          EXAMPLES
        end

        def self.signature
          {
            name: "update_artifact",
            description: "Updates an existing web artifact by generating precise diffs",
            parameters: [
              {
                name: "artifact_id",
                description: "The ID of the artifact to update",
                type: "integer",
                required: true,
              },
              {
                name: "instructions",
                description: "Clear instructions on what changes need to be made to the artifact",
                type: "string",
                required: true,
              },
            ],
          }
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

          diffs = generate_diffs(post: post, user: post.user, artifact: artifact)
          return error_response(diffs[:error]) if diffs[:error]

          p "here"

          begin
            version =
              artifact.apply_diff(
                html_diff: diffs[:html_diff],
                css_diff: diffs[:css_diff],
                js_diff: diffs[:js_diff],
                change_description: parameters[:instructions],
              )

            p "good"
            update_custom_html(artifact, version)
            success_response(artifact, version)
          rescue DiscourseAi::Utils::DiffUtils::DiffError => e
            p e
            error_response(e.to_llm_message)
          rescue => e
            p e
            error_response(e.message)
          end
        end

        private

        def generate_diffs(post:, user:, artifact:)
          prompt = build_diff_prompt(post: post, artifact: artifact)
          response = +""

          llm.generate(prompt, user: user, feature_name: "update_artifact") do |partial_response|
            response << partial_response
          end

          sections = parse_diff_sections(response)

          if valid_diff_sections?(sections)
            html_diff, css_diff, js_diff = sections
            {
              html_diff: html_diff.presence,
              css_diff: css_diff.presence,
              js_diff: js_diff.presence,
            }
          else
            { error: "Failed to generate valid diffs", response: response }
          end
        end

        def build_diff_prompt(post:, artifact:)
          DiscourseAi::Completions::Prompt.new(
            diff_system_prompt,
            messages: [
              {
                type: :user,
                content:
                  "Current artifact code:\n\n" \
                    "--- HTML ---\n#{artifact.html}\n" \
                    "--- CSS ---\n#{artifact.css}\n" \
                    "--- JavaScript ---\n#{artifact.js}\n",
              },
              { type: :model, content: "Please explain the diffs you would like to generate:" },
              { type: :user, content: parameters[:instructions] },
            ],
            post_id: post.id,
            topic_id: post.topic_id,
          )
        end

        def diff_system_prompt
          <<~PROMPT
            You are a web development expert generating precise diffs for updating HTML, CSS, and JavaScript code.

            Important rules:
            1. Only output changes using - for removals and + for additions
            2. Include 1-2 lines of context around changes
            3. Generate three sections: HTML_DIFF, CSS_DIFF, and JS_DIFF
            4. Only include sections that have changes
            5. Use exact line matches for context
            6. Keep diffs minimal and focused

            Format:
            --- HTML_DIFF ---
            (diff or empty if no changes)
            --- CSS_DIFF ---
            (diff or empty if no changes)
            --- JS_DIFF ---
            (diff or empty if no changes)

            --------------
            When supplying diffs, use a unified diff format. For example:

            #{self.class.diff_examples}
          PROMPT
        end

        def parse_diff_sections(response)
          html = +""
          css = +""
          javascript = +""
          current_section = nil

          response.each_line do |line|
            case line
            when /--- (HTML_DIFF|CSS_DIFF|JS_DIFF) ---/
              current_section = Regexp.last_match(1)
            else
              case current_section
              when "HTML_DIFF"
                html << line
              when "CSS_DIFF"
                css << line
              when "JS_DIFF"
                javascript << line
              end
            end
          end

          [html.strip, css.strip, javascript.strip]
        end

        def valid_diff_sections?(sections)
          return false if sections.empty?

          sections.any? do |section|
            next true if section.blank?
            section.include?("-") || section.include?("+")
          end
        end

        def update_custom_html(artifact, version)
          content = []

          if version.change_description.present?
            content << [:description, "### Change Description\n\n#{version.change_description}"]
          end

          diffs = []
          diffs << ["HTML Changes", version.html] if version.html != artifact.html
          diffs << ["CSS Changes", version.css] if version.css != artifact.css
          diffs << ["JavaScript Changes", version.js] if version.js != artifact.js

          content << [nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_changes")}']"]

          diffs.each do |title, new_content|
            old_content = artifact.send(title.downcase.split.first)
            #diff = generate_readable_diff(old_content, new_content)
            diff = "TODO"
            content << [nil, "### #{title}\n```diff\n#{diff}\n```"]
          end

          content << [nil, "[/details]"]

          content << [
            :preview,
            "### Preview\n\n<div class=\"ai-artifact\" data-ai-artifact-version=\"#{version.version_number}\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
          ]

          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
        end

        def generate_readable_diff(old_content, new_content)
          #Diffy::Diff.new(old_content, new_content, context: 2).to_s(:text)
        end

        def success_response(artifact, version)
          {
            status: "success",
            artifact_id: artifact.id,
            version: version.version_number,
            message: "Artifact updated successfully and rendered to user.",
          }
        end

        def error_response(message)
          self.custom_raw = ""
          { status: "error", error: message }
        end
      end
    end
  end
end
