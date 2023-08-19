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

        def concatenate_summaries(summaries, &on_partial_blk)
          instructions = <<~TEXT
            Human: Concatenate the following disjoint summaries inside the given input tags, creating a cohesive narrative.
            Include only the summary inside <ai> tags.
          TEXT

          instructions += summaries.reduce("") { |m, s| m += "<input>#{s}</input>\n" }
          instructions += "Assistant:\n"

          completion(instructions, &on_partial_blk)
        end

        def summarize_with_truncation(contents, opts, &on_partial_blk)
          instructions = build_base_prompt(opts)

          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          instructions += "<input>#{truncated_content}</input>\nAssistant:\n"

          completion(instructions, &on_partial_blk)
        end

        def summarize_single(chunk_text, opts, &on_partial_blk)
          summarize_chunk(chunk_text, opts.merge(single_chunk: true), &on_partial_blk)
        end

        private

        def summarize_chunk(chunk_text, opts, &on_partial_blk)
          completion(
            build_base_prompt(opts) + "<input>#{chunk_text}</input>\nAssistant:\n",
            &on_partial_blk
          )
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
            Try to keep the summary in the same languague as the forum discussion.
            Format the response, including links, using markdown.
            Include only the summary inside <ai> tags.
          TEXT

          if opts[:resource_path]
            base_prompt += "Try generating links as well the format is #{opts[:resource_path]}.\n"
          end

          base_prompt += "The discussion title is: #{opts[:content_title]}.\n" if opts[
            :content_title
          ]

          base_prompt += "Don't use more than 400 words.\n" unless opts[:single_chunk]

          base_prompt
        end

        def completion(prompt, &on_partial_blk)
          # We need to discard any text that might come before the <ai> tag.
          # Instructing the model to reply only with the summary seems impossible.
          pre_tag_partial = +""

          if on_partial_blk
            on_partial_read =
              Proc.new do |partial|
                if pre_tag_partial.include?("<ai>")
                  on_partial_blk.call(partial[:completion])
                else
                  pre_tag_partial << partial[:completion]
                end
              end

            response =
              ::DiscourseAi::Inference::AnthropicCompletions.perform!(
                prompt,
                model,
                &on_partial_read
              )
          else
            response =
              ::DiscourseAi::Inference::AnthropicCompletions.perform!(prompt, model).dig(
                :completion,
              )
          end

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
