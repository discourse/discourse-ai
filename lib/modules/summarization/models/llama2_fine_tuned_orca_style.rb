# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Llama2FineTunedOrcaStyle < Llama2
        def display_name
          "Llama2FineTunedOrcaStyle's #{SiteSetting.ai_hugging_face_model_display_name.presence || model}"
        end

        def concatenate_summaries(summaries, &on_partial_blk)
          prompt = <<~TEXT
            ### System:
            You are a helpful bot
            
            ### User:
            Concatenate these disjoint summaries, creating a cohesive narrative:
            #{summaries.join("\n")}

            ### Assistant:
          TEXT

          completion(prompt, &on_partial_blk)
        end

        def summarize_with_truncation(contents, opts, &on_partial_blk)
          text_to_summarize = contents.map { |c| format_content_item(c) }.join
          truncated_content = tokenizer.truncate(text_to_summarize, available_tokens)

          prompt = <<~TEXT
          ### System:
          #{build_base_prompt(opts)}
          
          ### User:
          Summarize the following in up to 400 words:
          #{truncated_content}

          ### Assistant:
          Here is a summary of the above topic:
        TEXT

          completion(prompt, &on_partial_blk)
        end

        private

        def summarize_chunk(chunk_text, opts, &on_partial_blk)
          summary_instruction =
            if opts[:single_chunk]
              "Summarize the following forum discussion, creating a cohesive narrative:"
            else
              "Summarize the following in up to 400 words:"
            end

          prompt = <<~TEXT
            ### System:
            #{build_base_prompt(opts)}

            ### User:
            #{summary_instruction}
            #{chunk_text}

            ### Assistant:
            Here is a summary of the above topic:
          TEXT

          completion(prompt, &on_partial_blk)
        end
      end
    end
  end
end
