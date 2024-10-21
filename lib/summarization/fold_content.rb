# frozen_string_literal: true

module DiscourseAi
  module Summarization
    # This class offers a generic way of summarizing content from multiple sources using different prompts.
    #
    # It summarizes large amounts of content by recursively summarizing it in smaller chunks that
    # fit the given model context window, finally concatenating the disjoint summaries
    # into a final version.
    #
    class FoldContent
      def initialize(llm, strategy, persist_summaries: true)
        @llm = llm
        @strategy = strategy
        @persist_summaries = persist_summaries
      end

      attr_reader :llm, :strategy

      # @param user { User } - User object used for auditing usage.
      #
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
      #
      # @returns { AiSummary } - Resulting summary.
      def summarize(user, &on_partial_blk)
        opts = content_to_summarize.except(:contents)

        initial_chunks =
          rebalance_chunks(
            content_to_summarize[:contents].map do |c|
              { ids: [c[:id]], summary: format_content_item(c) }
            end,
          )

        # Special case where we can do all the summarization in one pass.
        result =
          if initial_chunks.length == 1
            {
              summary:
                summarize_single(initial_chunks.first[:summary], user, opts, &on_partial_blk),
              chunks: [],
            }
          else
            summarize_chunks(initial_chunks, user, opts, &on_partial_blk)
          end

        clean_summary =
          Nokogiri::HTML5.fragment(result[:summary]).css("ai")&.first&.text || result[:summary]

        if persist_summaries
          AiSummary.store!(
            strategy.target,
            strategy.type,
            llm_model.name,
            clean_summary,
            content_to_summarize[:contents].map { |c| c[:id] },
          )
        else
          AiSummary.new(summarized_text: clean_summary)
        end
      end

      # @returns { AiSummary } - Resulting summary.
      #
      # Finds a summary matching the target and strategy. Marks it as outdates if the strategy found newer content
      def existing_summary
        if !defined?(@existing_summary)
          summary = AiSummary.find_by(target: strategy.target, summary_type: strategy.type)

          if summary
            @existing_summary = summary

            if existing_summary.original_content_sha != latest_sha
              @existing_summary.mark_as_outdated
            end
          end
        end
        @existing_summary
      end

      def delete_cached_summaries!
        AiSummary.where(target: strategy.target, summary_type: strategy.type).destroy_all
      end

      private

      attr_reader :persist_summaries

      def llm_model
        llm.llm_model
      end

      def content_to_summarize
        @targets_data ||= strategy.targets_data
      end

      def latest_sha
        @latest_sha ||= AiSummary.build_sha(content_to_summarize[:contents].map { |c| c[:id] }.join)
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
        prompt = strategy.summarize_single_prompt(text, opts)

        llm.generate(prompt, user: user, feature_name: "summarize", &on_partial_blk)
      end

      def summarize_in_chunks(chunks, user, opts)
        chunks.map do |chunk|
          prompt = strategy.summarize_single_prompt(chunk[:summary], opts)

          chunk[:summary] = llm.generate(
            prompt,
            user: user,
            max_tokens: 300,
            feature_name: "summarize",
          )

          chunk
        end
      end

      def concatenate_summaries(texts_to_summarize, user, &on_partial_blk)
        prompt = strategy.concatenation_prompt(texts_to_summarize)

        llm.generate(prompt, user: user, &on_partial_blk)
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
