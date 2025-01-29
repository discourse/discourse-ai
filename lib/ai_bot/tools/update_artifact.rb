# frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class UpdateArtifact < Tool
        def self.name
          "update_artifact"
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
              {
                name: "version",
                description:
                  "The version number of the artifact to update, if not supplied latest version will be updated",
                type: "integer",
                required: false,
              },
            ],
          }
        end

        def invoke
          yield "Updating Artifact\n#{parameters[:instructions]}\n\n"

          post = Post.find_by(id: context[:post_id])
          return error_response("No post context found") unless post

          artifact = AiArtifact.find_by(id: parameters[:artifact_id])
          return error_response("Artifact not found") unless artifact

          artifact_version = nil
          if version = parameters[:version]
            artifact_version = artifact.versions.find_by(version_number: version)
            return error_response("Version not found") unless version
          else
            artifact_version = artifact.versions.order(version_number: :desc).first
          end

          if artifact.post.topic.id != post.topic.id
            return error_response("Attempting to update an artifact you are not allowed to")
          end

          begin
            new_version =
              ArtifactUpdateStrategies::Full.new(
                llm: llm,
                post: post,
                user: post.user,
                artifact: artifact,
                artifact_version: artifact_version,
                instructions: parameters[:instructions],
              ).apply

            update_custom_html(
              artifact: artifact,
              artifact_version: artifact_version,
              new_version: new_version,
            )
            success_response(artifact, new_version)
          rescue StandardError => e
            error_response(e.message)
          end
        end

        def chain_next_response?
          false
        end

        private

        def line_based_markdown_diff(before, after)
          # Split into lines
          before_lines = before.split("\n")
          after_lines = after.split("\n")

          # Use ONPDiff for line-level comparison
          diff = ONPDiff.new(before_lines, after_lines).diff

          # Build markdown output
          result = ["```diff"]

          diff.each do |line, status|
            case status
            when :common
              result << " #{line}"
            when :delete
              result << "-#{line}"
            when :add
              result << "+#{line}"
            end
          end

          result << "```"
          result.join("\n")
        end

        def update_custom_html(artifact:, artifact_version:, new_version:)
          content = []

          if new_version.change_description.present?
            content << [:description, "### Change Description\n\n#{new_version.change_description}"]
          end
          content << [nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_changes")}']"]

          %w[html css js].each do |type|
            source = artifact_version || artifact
            old_content = source.public_send(type)
            new_content = new_version.public_send(type)

            if old_content != new_content
              diff = line_based_markdown_diff(old_content, new_content)
              content << [nil, "### #{type.upcase} Changes\n#{diff}"]
            end
          end

          content << [nil, "[/details]"]
          content << [
            :preview,
            "### Preview\n\n<div class=\"ai-artifact\" data-ai-artifact-version=\"#{new_version.version_number}\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
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
