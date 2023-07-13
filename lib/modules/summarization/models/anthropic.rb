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
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          instructions += "<input>#{truncated_content}</input>\nAssistant:\n"

          completion(instructions)
        end

        def summarize_single(chunk_text, opts)
          summarize_chunk(chunk_text, opts.merge(single_chunk: true))
        end

        private

        def summarize_chunk(chunk_text, opts)
          completion(build_base_prompt(opts) + "<input>#{chunk_text}</input>\nAssistant:\n")
        end

        def build_base_prompt(opts)
          initial_instruction =
            if opts[:single_chunk]
              "Summarize the following forum discussion inside the given <input> tag, creating a cohesive narrative."
            else
              "Summarize the following forum discussion inside the given <input> tag."
            end

          base_prompt = <<~TEXT
            Human: #{initial_instruction}
            Include only the summary inside <ai> tags.
          TEXT

          if opts[:resource_path]
            base_prompt += "Try generating links as well the format is #{opts[:resource_path]}.\n"
          end

          base_prompt += "The discussion title is: #{opts[:content_title]}.\n" if opts[
            :content_title
          ]

          base_prompt += "Don't use more than 400 words.\n" unless opts[:single_chunk]
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
