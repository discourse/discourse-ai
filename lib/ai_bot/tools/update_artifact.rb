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
            Example - Multiple changes in one file:
            --- JavaScript ---
            <<<<<<< SEARCH
            console.log('old1');
            =======
            console.log('new1');
            >>>>>>> REPLACE
            <<<<<<< SEARCH
            console.log('old2');
            =======
            console.log('new2');
            >>>>>>> REPLACE

            Example - CSS with multiple blocks:
            --- CSS ---
            <<<<<<< SEARCH
            .button { color: blue; }
            =======
            .button { color: red; }
            >>>>>>> REPLACE
            <<<<<<< SEARCH
            .text { font-size: 12px; }
            =======
            .text { font-size: 16px; }
            >>>>>>> REPLACE
          EXAMPLES
        end

        def self.signature
          {
            name: "update_artifact",
            description:
              "Updates an existing web artifact using search/replace operations. Supports multiple changes per section.",
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

          changes = generate_changes(post: post, user: post.user, artifact: artifact)
          return error_response(changes[:error]) if changes[:error]

          begin
            version = apply_changes(artifact, changes)
            update_custom_html(artifact, version)
            success_response(artifact, version)
          rescue => e
            error_response(e.message)
          end
        end

        private

        def generate_changes(post:, user:, artifact:)
          prompt = build_changes_prompt(post: post, artifact: artifact)
          response = +""

          llm.generate(prompt, user: user, feature_name: "update_artifact") do |partial|
            response << partial
          end

          parse_changes(response)
        end

        def parse_changes(response)
          sections = { html: nil, css: nil, javascript: nil }
          current_section = nil
          lines = []

          response.each_line do |line|
            case line
            when /^--- (HTML|CSS|JavaScript) ---$/
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = line.match(/^--- (.+) ---$/)[1].downcase.to_sym
              lines = []
            else
              lines << line if current_section
            end
          end

          sections[current_section] = lines.join if current_section && !lines.empty?

          # Validate and extract all search/replace blocks
          sections.transform_values do |content|
            next nil if content.nil?

            puts content

            blocks = extract_search_replace_blocks(content)
            return { error: "Invalid format in #{current_section} section" } if blocks.nil?

            puts "GOOD"
            blocks
          end
        end

        def extract_search_replace_blocks(content)
          return nil if content.blank?

          blocks = []
          remaining = content

          while remaining =~ /<<<<<<< SEARCH\n(.*?)\n=======\n(.*?)\n>>>>>>> REPLACE/m
            blocks << { search: $1, replace: $2 }
            remaining = $'
          end

          blocks.empty? ? nil : blocks
        end

        def apply_changes(artifact, changes)
          updated_content = {}

          %i[html css javascript].each do |section|
            blocks = changes[section]
            next unless blocks

            content = artifact.send(section == :javascript ? :js : section)
            blocks.each do |block|
              content =
                DiscourseAi::Utils::DiffUtils::SimpleDiff.apply(
                  content,
                  block[:search],
                  block[:replace],
                )
            end
            updated_content[section == :javascript ? :js : section] = content
          end

          artifact.create_new_version(
            html: updated_content[:html],
            css: updated_content[:css],
            js: updated_content[:js],
            change_description: parameters[:instructions],
          )
        end

        def build_changes_prompt(post:, artifact:)
          DiscourseAi::Completions::Prompt.new(
            changes_system_prompt,
            messages: [
              { type: :user, content: <<~CONTENT },
                Current artifact code:

                --- HTML ---
                #{artifact.html}

                --- CSS ---
                #{artifact.css}

                --- JavaScript ---
                #{artifact.js}
              CONTENT
              { type: :model, content: "Please explain the changes you would like to generate:" },
              { type: :user, content: parameters[:instructions] },
            ],
            post_id: post.id,
            topic_id: post.topic_id,
          )
        end

        def changes_system_prompt
          <<~PROMPT
            You are a web development expert generating precise search/replace changes for updating HTML, CSS, and JavaScript code.

            Important rules:
            1. Use the format <<<<<<< SEARCH / ======= / >>>>>>> REPLACE for each change
            2. You can specify multiple search/replace blocks per section
            3. Generate three sections: HTML, CSS, and JavaScript
            4. Only include sections that have changes
            5. Keep changes minimal and focused
            6. Use exact matches for the search content

            Format:
            --- HTML ---
            (changes or empty if no changes)
            --- CSS ---
            (changes or empty if no changes)
            --- JavaScript ---
            (changes or empty if no changes)

            Example changes:
            #{self.class.diff_examples}
          PROMPT
        end

        def update_custom_html(artifact, version)
          content = []

          if version.change_description.present?
            content << [:description, "### Change Description\n\n#{version.change_description}"]
          end
          content << [nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_changes")}']"]

          %w[html css js].each do |type|
            old_content = artifact.public_send(type)
            new_content = version.public_send(type)

            if old_content != new_content
              diff = "xxx" # Placeholder for actual diff implementation
              content << [nil, "### #{type.upcase} Changes\n```diff\n#{diff}\n```"]
            end
          end

          content << [nil, "[/details]"]
          content << [
            :preview,
            "### Preview\n\n<div class=\"ai-artifact\" data-ai-artifact-version=\"#{version.version_number}\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
          ]

          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
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
