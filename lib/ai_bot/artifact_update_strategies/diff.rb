# frozen_string_literal: true
module DiscourseAi
  module AiBot
    module ArtifactUpdateStrategies
      class Diff < Base
        attr_reader :failed_searches

        private

        def initialize(**kwargs)
          super
          @failed_searches = []
        end

        def build_prompt
          DiscourseAi::Completions::Prompt.new(
            system_prompt,
            messages: [{ type: :user, content: user_prompt }],
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
            when /^\[(HTML|CSS|JavaScript)\]$/
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = line.match(/^\[(.+)\]$/)[1].downcase.to_sym
              lines = []
            when %r{^\[/(?:HTML|CSS|JavaScript)\]$}
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = nil
            else
              lines << line if current_section
            end
          end

          sections.each do |section, content|
            sections[section] = extract_search_replace_blocks(content)
          end

          sections
        end

        def apply_changes(changes)
          source = artifact_version || artifact
          updated_content = { js: source.js, html: source.html, css: source.css }

          %i[html css javascript].each do |section|
            blocks = changes[section]
            next unless blocks

            content = source.public_send(section == :javascript ? :js : section)
            blocks.each do |block|
              begin
                content =
                  DiscourseAi::Utils::DiffUtils::SimpleDiff.apply(
                    content,
                    block[:search],
                    block[:replace],
                  )
              rescue DiscourseAi::Utils::DiffUtils::SimpleDiff::NoMatchError
                @failed_searches << { section: section, search: block[:search] }
                # TODO, we may need to inform caller here, LLM made a mistake which it
                # should correct
                puts "Failed to find search: #{block[:search]}"
              end
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

          pattern = /<<+\s*SEARCH\s*\n(.*?)\n=+\s*\n(.*?)\n>>+\s*REPLACE/m
          while remaining =~ pattern
            blocks << { search: $1.strip, replace: $2.strip }
            remaining = $'
          end

          blocks.empty? ? nil : blocks
        end

        def system_prompt
          <<~PROMPT
            You are a web development expert generating precise search/replace changes for updating HTML, CSS, and JavaScript code.

            Important rules:

            1. Use EXACTLY this format for changes:
               <<<<<<< SEARCH
               (first line of code to replace)
               (other lines of code to avoid ambiguity)
               (last line of code to replace)
               =======
               (replacement code)
               >>>>>>> REPLACE
            2. DO NOT modify the markers or add spaces around them
            3. DO NOT add explanations or comments within sections
            4. ONLY include [HTML], [CSS], and [JavaScript] sections if they have changes
            5. Keep changes minimal and focused
            6. HTML should not include <html>, <head>, or <body> tags, it is injected into a template
            7. When specifying a SEARCH block, ALWAYS keep it 8 lines or less, you will be interrupted and a retry will be required if you exceed this limit
            8. NEVER EVER ask followup questions, ALL changes must be performed in a single response, you are consumed via an API, there is no opportunity for humans in the loop
            9. When performing a non-contiguous search, ALWAYS use ... to denote the skipped lines
            10. Be mindful that ... non-contiguous search is not greedy, the following line will only match the first occurrence of the search block

            JavaScript libraries must be sourced from the following CDNs, otherwise CSP will reject it:
            #{AiArtifact::ALLOWED_CDN_SOURCES.join("\n")}

            Reply Format:
            [HTML]
            (changes or empty if no changes)
            [/HTML]
            [CSS]
            (changes or empty if no changes)
            [/CSS]
            [JavaScript]
            (changes or empty if no changes)
            [/JavaScript]

            Example - Multiple changes in one file:

            [JavaScript]
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
            [/JavaScript]

            Example - CSS with multiple blocks:

            [CSS]
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
            [/CSS]

            Example - Non contiguous search in CSS (replace most CSS with new CSS)

            Original CSS:

            [CSS]
            body {
              color: red;
            }
            .button {
              color: blue;
            }
            .alert {
              background-color: green;
            }
            .alert2 {
              background-color: green;
            }
            [/CSS]

            [CSS]
            <<<<<<< SEARCH
            body {
            ...
              background-color: green;
            }
            =======
            body {
              color: red;
            }
            >>>>>>> REPLACE

            RESULT:

            [CSS]
            body {
              color: red;
            }
            .alert2 {
              background-color: green;
            }
            [/CSS]

          PROMPT
        end

        def user_prompt
          source = artifact_version || artifact
          <<~CONTENT
            Artifact code:

            [HTML]
            #{source.html}
            [/HTML]

            [CSS]
            #{source.css}
            [/CSS]

            [JavaScript]
            #{source.js}
            [/JavaScript]

            Instructions:

            #{instructions}
          CONTENT
        end
      end
    end
  end
end
