# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class OpenAi < Base
        def display_name
          "Open AI's #{model}"
        end

        def correctly_configured?
          SiteSetting.ai_openai_api_key.present?
        end

        def configuration_hint
          I18n.t(
            "discourse_ai.summarization.configuration_hint",
            count: 1,
            setting: "ai_openai_api_key",
          )
        end

        def concatenate_summaries(summaries)
          messages = [
            { role: "system", content: "You are a helpful bot" },
            {
              role: "user",
              content:
                "Concatenate these disjoint summaries, creating a cohesive narrative:\n#{summaries.join("\n")}",
            },
          ]

          completion(messages)
        end

        def summarize_with_truncation(contents, opts)
          messages = [{ role: "system", content: build_base_prompt(opts) }]

          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          messages << {
            role: "user",
            content: "Summarize the following in 400 words:\n#{truncated_content}",
          }

          completion(messages)
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
              "Summarize the following in 400 words:"
            end

          completion(
            [
              { role: "system", content: build_base_prompt(opts) },
              { role: "user", content: "#{summary_instruction}\n#{chunk_text}" },
            ],
          )
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
          ::DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model).dig(
            :choices,
            0,
            :message,
            :content,
          )
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
