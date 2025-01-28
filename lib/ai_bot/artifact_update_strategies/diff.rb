# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module ArtifactUpdateStrategies
      class Diff < Base
        private

        def build_prompt
          DiscourseAi::Completions::Prompt.new(
            system_prompt,
            messages: [
              { type: :user, content: current_artifact_content },
              { type: :model, content: "Please explain the changes you would like to generate:" },
              { type: :user, content: instructions },
            ],
            post_id: post.id,
            topic_id: post.topic_id,
          )
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

          sections.transform_values do |content|
            next nil if content.nil?
            blocks = extract_search_replace_blocks(content)
            raise InvalidFormatError, "Invalid format in #{current_section} section" if blocks.nil?
            blocks
          end
        end

        def apply_changes(changes)
          source = artifact_version || artifact
          updated_content = { js: source.js, html: source.html, css: source.css }

          %i[html css javascript].each do |section|
            blocks = changes[section]
            next unless blocks

            content = source.public_send(section == :javascript ? :js : section)
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
            change_description: instructions,
          )
        end

        private

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

        def system_prompt
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
          PROMPT
        end

        def current_artifact_content
          source = artifact_version || artifact
          <<~CONTENT
            Current artifact code:

            --- HTML ---
            #{source.html}

            --- CSS ---
            #{source.css}

            --- JavaScript ---
            #{source.js}
          CONTENT
        end
      end
    end
  end
end
