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

          initial_chunks =
            rebalance_chunks(
              llm.tokenizer,
              content[:contents].map { |c| { ids: [c[:id]], summary: format_content_item(c) } },
            )

          # Special case where we can do all the summarization in one pass.
          if initial_chunks.length == 1
            {
              summary:
                summarize_single(llm, initial_chunks.first[:summary], user, opts, &on_partial_blk),
              chunks: [],
            }
          else
            summarize_chunks(llm, initial_chunks, user, opts, &on_partial_blk)
          end
        end

        private

        def summarize_chunks(llm, chunks, user, opts, &on_partial_blk)
          # Safely assume we always have more than one chunk.
          summarized_chunks = summarize_in_chunks(llm, chunks, user, opts)
          total_summaries_size =
            llm.tokenizer.size(summarized_chunks.map { |s| s[:summary].to_s }.join)

          if total_summaries_size < completion_model.available_tokens
            # Chunks are small enough, we can concatenate them.
            {
              summary:
                concatenate_summaries(
                  llm,
                  summarized_chunks.map { |s| s[:summary] },
                  user,
                  &on_partial_blk
                ),
              chunks: summarized_chunks,
            }
          else
            # We have summarized chunks but we can't concatenate them yet. Split them into smaller summaries and summarize again.
            rebalanced_chunks = rebalance_chunks(llm.tokenizer, summarized_chunks)

            summarize_chunks(llm, rebalanced_chunks, user, opts, &on_partial_blk)
          end
        end

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def rebalance_chunks(tokenizer, chunks)
          section = { ids: [], summary: "" }

          chunks =
            chunks.reduce([]) do |sections, chunk|
              if tokenizer.can_expand_tokens?(
                   section[:summary],
                   chunk[:summary],
                   completion_model.available_tokens,
                 )
                section[:summary] += chunk[:summary]
                section[:ids] = section[:ids].concat(chunk[:ids])
              else
                sections << section
                section = chunk
              end

              sections
            end

          chunks << section if section[:summary].present?

          chunks
        end

        def summarize_single(llm, text, user, opts, &on_partial_blk)
          prompt = summarization_prompt(text, opts)

          llm.generate(prompt, user: user, &on_partial_blk)
        end

        def summarize_in_chunks(llm, chunks, user, opts)
          chunks.map do |chunk|
            prompt = summarization_prompt(chunk[:summary], opts)
            prompt[:post_insts] = "Don't use more than 400 words for the summary."

            chunk[:summary] = llm.generate(prompt, user: user)
            chunk
          end
        end

        def concatenate_summaries(llm, summaries, user, &on_partial_blk)
          prompt = {}
          prompt[:insts] = <<~TEXT
            You are a summarization bot that effectively concatenates disjoint summaries, creating a cohesive narrative.
            The narrative you create is in the form of one or multiple paragraphs.
            Your reply MUST BE a single concatenated summary using the summaries I'll provide to you.
            I'm NOT interested in anything other than the concatenated summary, don't include additional text or comments.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using Markdown.
          TEXT

          prompt[:input] = <<~TEXT
            THESE are the summaries, each one separated by a newline, all of them inside <input></input> XML tags:

            <input>
              #{summaries.join("\n")}
            </input>
          TEXT

          llm.generate(prompt, user: user, &on_partial_blk)
        end

        def summarization_prompt(input, opts)
          insts = <<~TEXT
            You are a summarization bot that effectively summarize any text
            Your reply MUST BE a summarized version of the posts I provided, using the first language you detect.
            I'm NOT interested in anything other than the summary, don't include additional text or comments.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using Markdown.
            Your summaries are always a cohesive narrative in the form of one or multiple paragraphs.

          TEXT

          insts += <<~TEXT if opts[:resource_path]
                Each post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE> "
                Try generating links as well the format is #{opts[:resource_path]}/<POST_NUMBER>
                For example, a link to the 3rd post in the topic would be [post 3](#{opts[:resource_path]}/3)
              TEXT

          prompt = { insts: insts, input: <<~TEXT }
              #{opts[:content_title].present? ? "The discussion title is: " + opts[:content_title] + ".\n" : ""}
              Here are the posts, inside <input></input> XML tags:

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
