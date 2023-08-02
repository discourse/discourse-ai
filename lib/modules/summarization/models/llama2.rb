# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Llama2 < Base
        def display_name
          "Llama2's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_hugging_face_api_url.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_hugging_face_api_url",
          )
        end

        def concatenate_summaries(summaries)
          completion(<<~TEXT)
            [INST] <<SYS>>
            You are a helpful bot
            <</SYS>>

            Concatenate these disjoint summaries, creating a cohesive narrative:
            #{summaries.join("\n")} [/INST]
          TEXT
        end

        def summarize_with_truncation(contents, opts)
          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          completion(<<~TEXT)
            [INST] <<SYS>>
            #{build_base_prompt(opts)}
            <</SYS>>

            Summarize the following in up to 400 words:
            #{truncated_content} [/INST]
          TEXT
        end

        def summarize_single(chunk_text, opts)
          summarize_chunk(chunk_text, opts.merge(single_chunk: true))
        end

        private

        def summarize_chunk(chunk_text, opts)
          summary_instruction =
            if opts[:single_chunk]
              "Summarize the following forum discussion, creating a cohesive narrative:"
            else
              "Summarize the following in up to 400 words:"
            end

          completion(<<~TEXT)
            [INST] <<SYS>>
            #{build_base_prompt(opts)}
            <</SYS>>

            #{summary_instruction}
            #{chunk_text} [/INST]
          TEXT
        end

        def build_base_prompt(opts)
          base_prompt = <<~TEXT
            You are a summarization bot.
            You effectively summarise any text and reply ONLY with ONLY the summarized text.
            You condense it into a shorter version.
            You understand and generate Discourse forum Markdown.
          TEXT

          if opts[:resource_path]
            base_prompt +=
              "Try generating links as well the format is #{opts[:resource_path]}. eg: [ref](#{opts[:resource_path]}/77)\n"
          end

          base_prompt += "The discussion title is: #{opts[:content_title]}.\n" if opts[
            :content_title
          ]

          base_prompt
        end

        def completion(prompt)
          ::DiscourseAi::Inference::HuggingFaceTextGeneration.perform!(
            prompt,
            model,
            token_limit: token_limit,
          ).dig(:generated_text)
        end

        def tokenizer
          DiscourseAi::Tokenizer::Llama2Tokenizer
        end

        def token_limit
          4096
        end
      end
    end
  end
end
