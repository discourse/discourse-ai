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

        def concatenate_summaries(summaries, &on_partial_blk)
          messages = [
            { role: "system", content: "You are a helpful bot" },
            {
              role: "user",
              content:
                "Concatenate these disjoint summaries, creating a cohesive narrative. Keep the summary in the same language used in the text below.\n#{summaries.join("\n")}",
            },
          ]

          completion(messages, &on_partial_blk)
        end

        def summarize_with_truncation(contents, opts, &on_partial_blk)
          messages = [{ role: "system", content: build_base_prompt(opts) }]

          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          messages << {
            role: "user",
            content:
              "Summarize the following in 400 words. Keep the summary in the same language used in the text below.\n#{truncated_content}",
          }

          completion(messages, &on_partial_blk)
        end

        def summarize_single(chunk_text, opts, &on_partial_blk)
          summarize_chunk(chunk_text, opts.merge(single_chunk: true), &on_partial_blk)
        end

        private

        def summarize_chunk(chunk_text, opts, &on_partial_blk)
          summary_instruction =
            if opts[:single_chunk]
              "Summarize the following forum discussion, creating a cohesive narrative. Keep the summary in the same language used in the text below."
            else
              "Summarize the following in 400 words. Keep the summary in the same language used in the text below."
            end

          completion(
            [
              { role: "system", content: build_base_prompt(opts) },
              { role: "user", content: "#{summary_instruction}\n#{chunk_text}" },
            ],
            &on_partial_blk
          )
        end

        def build_base_prompt(opts)
          base_prompt = <<~TEXT
            You are a summarization bot.
            You effectively summarise any text and reply ONLY with ONLY the summarized text.
            You condense it into a shorter version.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using markdown.
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

        def completion(prompt, &on_partial_blk)
          if on_partial_blk
            on_partial_read =
              Proc.new do |partial|
                on_partial_blk.call(partial.dig(:choices, 0, :delta, :content).to_s)
              end

            ::DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model, &on_partial_read)
          else
            ::DiscourseAi::Inference::OpenAiCompletions.perform!(prompt, model).dig(
              :choices,
              0,
              :message,
              :content,
            )
          end
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end
      end
    end
  end
end
