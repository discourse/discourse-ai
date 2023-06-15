# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Anthropic < Base
        def display_name
          "Anthropic's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_anthropic_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_anthropic_api_key",
          )
        end

        def summarize_in_chunks(contents, opts = {})
          base_instructions = build_base_prompt(opts)
          chunks = []

          section = ""
          last_chunk =
            contents.each do |item|
              new_content = format_content_item(item)

              if tokenizer.can_expand_tokens?(section, new_content, max_tokens - reserved_tokens)
                section += new_content
              else
                chunks << section
                section = new_content
              end
            end

          chunks << section if section.present?

          chunks.map do |chunk|
            chunk_text = "<input>#{chunk}</input>\nAssistant:\n"
            completion(base_instructions + chunk_text)
          end
        end

        def concatenate_summaries(summaries)
          instructions = <<~TEXT
            Human: Concatenate the following disjoint summaries inside the given input tags, creating a cohesive narrative.
            Include only the summary inside <ai> tags.
          TEXT

          instructions += summaries.reduce("") { |m, s| m += "<input>#{s}</input>\n" }
          instructions += "Assistant:\n"

          completion(instructions)
        end

        def summarize_with_truncation(contents, opts)
          instructions = build_base_prompt(opts)

          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, max_tokens - reserved_tokens)

          instructions += "<input>#{truncated_content}</input>\nAssistant:\n"

          completion(instructions)
        end

        private

        def build_base_prompt(opts)
          base_prompt = <<~TEXT
            Human: Summarize the following forum discussion inside the given <input> tag.
            Include only the summary inside <ai> tags.
          TEXT

          if opts[:resource_path]
            base_prompt += "Try generating links as well the format is #{opts[:resource_path]}.\n"
          end

          base_prompt += "The discussion title is: #{opts[:content_title]}.\n" if opts[
            :content_title
          ]

          base_prompt += "Don't use more than 400 words.\n"
        end

        def completion(prompt)
          response =
            ::DiscourseAi::Inference::AnthropicCompletions.perform!(prompt, model).dig(:completion)

          Nokogiri::HTML5.fragment(response).at("ai").text
        end

        def tokenizer
          DiscourseAi::Tokenizer::AnthropicTokenizer
        end

        attr_reader :max_tokens
      end
    end
  end
end
