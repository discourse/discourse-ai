# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class FoldContent < ::Summarization::Base
        def initialize(completion_model)
          @completion_model = completion_model
        end

        attr_reader :completion_model

        delegate :correctly_configured?,
                 :display_name,
                 :configuration_hint,
                 :model,
                 to: :completion_model

        def summarize(content, user, &on_partial_blk)
          opts = content.except(:contents)

          llm = DiscourseAi::Completions::Llm.proxy(completion_model.model)

          chunks = split_into_chunks(llm.tokenizer, content[:contents])

          if chunks.length == 1
            {
              summary: summarize_single(llm, chunks.first[:summary], user, opts, &on_partial_blk),
              chunks: [],
            }
          else
            summaries = summarize_in_chunks(llm, chunks, user, opts)

            {
              summary:
                concatenate_summaries(
                  llm,
                  summaries.map { |s| s[:summary] },
                  user,
                  &on_partial_blk
                ),
              chunks: summaries,
            }
          end
        end

        private

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def split_into_chunks(tokenizer, contents)
          section = { ids: [], summary: "" }

          chunks =
            contents.reduce([]) do |sections, item|
              new_content = format_content_item(item)

              if tokenizer.can_expand_tokens?(
                   section[:summary],
                   new_content,
                   completion_model.available_tokens,
                 )
                section[:summary] += new_content
                section[:ids] << item[:id]
              else
                sections << section
                section = { ids: [item[:id]], summary: new_content }
              end

              sections
            end

          chunks << section if section[:summary].present?

          chunks
        end

        def summarize_single(llm, text, user, opts, &on_partial_blk)
          prompt = summarization_prompt(text, opts)

          llm.completion!(prompt, user, &on_partial_blk)
        end

        def summarize_in_chunks(llm, chunks, user, opts)
          chunks.map do |chunk|
            prompt = summarization_prompt(chunk[:summary], opts)
            prompt[:post_insts] = "Don't use more than 400 words for the summary."

            chunk[:summary] = llm.completion!(prompt, user)
            chunk
          end
        end

        def concatenate_summaries(llm, summaries, user, &on_partial_blk)
          prompt = summarization_prompt(summaries.join("\n"), {})
          prompt[:insts] = <<~TEXT
            You are a bot that can concatenate disjoint summaries, creating a cohesive narrative.
            Keep the resulting summary in the same language used in the text below.
          TEXT

          llm.completion!(prompt, user, &on_partial_blk)
        end

        def summarization_prompt(input, opts)
          insts = <<~TEXT
            You are a summarization bot that effectively summarize any text
            Your replies contain ONLY a summarized version of the text I provided and you, using the same language.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using Markdown.
            Your summaries are always a cohesive narrative in the form of one or multiple paragraphs.

          TEXT

          insts += <<~TEXT if opts[:resource_path]
                Each post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE> "
                Try generating links as well the format is #{opts[:resource_path]}/<POST_NUMBER>
                For example, a link to the 3rd post in the topic would be [post 3](#{opts[:resource_path]}/3)
              TEXT

          insts += "The discussion title is: #{opts[:content_title]}.\n" if opts[:content_title]

          prompt = { insts: insts, input: <<~TEXT }
              Here is the a list of posts, inside <input></input> XML tags:

              <input>
                #{input}
              </input>
          TEXT

          if opts[:resource_path]
            prompt[:examples] = [
              [
                "<input>1) user1 said: I love Mondays 2) user2 said: I hate Mondays</input>",
                "Two users are sharing their feelings toward Mondays. [user1](#{opts[:resource_path]}/1) hates them, while [user2](#{opts[:resource_path]}/2) loves them.",
              ],
              [
                "<input>3) usuario1: Amo los lunes 6) usuario2: Odio los lunes</input>",
                "Dos usuarios charlan sobre los lunes. [usuario1](#{opts[:resource_path]}/3) dice que los ama, mientras que [usuario2](#{opts[:resource_path]}/2) los odia.",
              ],
            ]
          end

          prompt
        end
      end
    end
  end
end
