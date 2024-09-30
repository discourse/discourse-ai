# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      class FoldContent
        def initialize(completion_model)
          @llm = DiscourseAi::Completions::Llm.proxy(completion_model)
          raise "Invalid model provided for summarization strategy" if @llm.llm_model.nil?
        end

        attr_reader :llm

        def summarize(content, user, &on_partial_blk)
          opts = content.except(:contents)

          initial_chunks =
            rebalance_chunks(
              content[:contents].map { |c| { ids: [c[:id]], summary: format_content_item(c) } },
            )

          # Special case where we can do all the summarization in one pass.
          if initial_chunks.length == 1
            {
              summary:
                summarize_single(initial_chunks.first[:summary], user, opts, &on_partial_blk),
              chunks: [],
            }
          else
            summarize_chunks(initial_chunks, user, opts, &on_partial_blk)
          end
        end

        def display_name
          llm_model&.name || "unknown model"
        end

        private

        def llm_model
          llm.llm_model
        end

        def summarize_chunks(chunks, user, opts, &on_partial_blk)
          # Safely assume we always have more than one chunk.
          summarized_chunks = summarize_in_chunks(chunks, user, opts)
          total_summaries_size =
            llm_model.tokenizer_class.size(summarized_chunks.map { |s| s[:summary].to_s }.join)

          if total_summaries_size < available_tokens
            # Chunks are small enough, we can concatenate them.
            {
              summary:
                concatenate_summaries(
                  summarized_chunks.map { |s| s[:summary] },
                  user,
                  &on_partial_blk
                ),
              chunks: summarized_chunks,
            }
          else
            # We have summarized chunks but we can't concatenate them yet. Split them into smaller summaries and summarize again.
            rebalanced_chunks = rebalance_chunks(summarized_chunks)

            summarize_chunks(rebalanced_chunks, user, opts, &on_partial_blk)
          end
        end

        def format_content_item(item)
          "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
        end

        def rebalance_chunks(chunks)
          section = { ids: [], summary: "" }

          chunks =
            chunks.reduce([]) do |sections, chunk|
              if llm_model.tokenizer_class.can_expand_tokens?(
                   section[:summary],
                   chunk[:summary],
                   available_tokens,
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

        def summarize_single(text, user, opts, &on_partial_blk)
          prompt = summarization_prompt(text, opts)

          llm.generate(prompt, user: user, feature_name: "summarize", &on_partial_blk)
        end

        def summarize_in_chunks(chunks, user, opts)
          chunks.map do |chunk|
            prompt = summarization_prompt(chunk[:summary], opts)

            chunk[:summary] = llm.generate(
              prompt,
              user: user,
              max_tokens: 300,
              feature_name: "summarize",
            )
            chunk
          end
        end

        def concatenate_summaries(summaries, user, &on_partial_blk)
          prompt = DiscourseAi::Completions::Prompt.new(<<~TEXT.strip)
            You are a summarization bot that effectively concatenates disjoint summaries, creating a cohesive narrative.
            The narrative you create is in the form of one or multiple paragraphs.
            Your reply MUST BE a single concatenated summary using the summaries I'll provide to you.
            I'm NOT interested in anything other than the concatenated summary, don't include additional text or comments.
            You understand and generate Discourse forum Markdown.
            You format the response, including links, using Markdown.
          TEXT

          prompt.push(type: :user, content: <<~TEXT.strip)
            THESE are the summaries, each one separated by a newline, all of them inside <input></input> XML tags:

            <input>
              #{summaries.join("\n")}
            </input>
          TEXT

          llm.generate(prompt, user: user, &on_partial_blk)
        end

        def summarization_prompt(input, opts)
          insts = +<<~TEXT
            You are an advanced summarization bot that generates concise, coherent summaries of provided text.

            - Only include the summary, without any additional commentary.
            - You understand and generate Discourse forum Markdown; including links, _italics_, **bold**.
            - Maintain the original language of the text being summarized.
            - Aim for summaries to be 400 words or less.

          TEXT

          insts << <<~TEXT if opts[:resource_path]
                - Each post is formatted as "<POST_NUMBER>) <USERNAME> <MESSAGE>"
                - Cite specific noteworthy posts using the format [NAME](#{opts[:resource_path]}/POST_NUMBER)
                  - Example: link to the 3rd post by sam: [sam](#{opts[:resource_path]}/3)
                  - Example: link to the 6th post by jane: [agreed with](#{opts[:resource_path]}/6)
                  - Example: link to the 13th post by joe: [#13](#{opts[:resource_path]}/13)
                - When formatting usernames either use @USERNMAE OR [USERNAME](#{opts[:resource_path]}/POST_NUMBER)
              TEXT

          prompt = DiscourseAi::Completions::Prompt.new(insts.strip)

          if opts[:resource_path]
            prompt.push(
              type: :user,
              content:
                "Here are the posts inside <input></input> XML tags:\n\n<input>1) user1 said: I love Mondays 2) user2 said: I hate Mondays</input>\n\nGenerate a concise, coherent summary of the text above maintaining the original language.",
            )
            prompt.push(
              type: :model,
              content:
                "Two users are sharing their feelings toward Mondays. [user1](#{opts[:resource_path]}/1) hates them, while [user2](#{opts[:resource_path]}/2) loves them.",
            )
          end

          prompt.push(type: :user, content: <<~TEXT.strip)
          #{opts[:content_title].present? ? "The discussion title is: " + opts[:content_title] + ".\n" : ""}
          Here are the posts, inside <input></input> XML tags:

          <input>
            #{input}
          </input>

          Generate a concise, coherent summary of the text above maintaining the original language.
          TEXT

          prompt
        end

        def available_tokens
          # Reserve tokens for the response and the base prompt
          # ~500 words
          reserved_tokens = 700

          llm_model.max_prompt_tokens - reserved_tokens
        end
      end
    end
  end
end
