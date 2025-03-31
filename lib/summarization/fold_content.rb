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
      def initialize(bot, strategy, persist_summaries: true)
        @bot = bot
        @strategy = strategy
        @persist_summaries = persist_summaries
      end

      attr_reader :bot, :strategy

      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
      #
      # This method doesn't care if we already have an up to date summary. It always regenerate.
      #
      # @returns { AiSummary } - Resulting summary.
      def summarize(user, &on_partial_blk)
        base_summary = ""
        initial_pos = 0

        truncated_content = content_to_summarize.map { |cts| truncate(cts) }

        folded_summary = fold(truncated_content, base_summary, initial_pos, user, &on_partial_blk)

        clean_summary =
          Nokogiri::HTML5.fragment(folded_summary).css("ai")&.first&.text || folded_summary

        if persist_summaries
          AiSummary.store!(
            strategy,
            llm_model,
            clean_summary,
            truncated_content,
            human: user&.human?,
          )
        else
          AiSummary.new(summarized_text: clean_summary)
        end
      end

      # @returns { AiSummary } - Resulting summary.
      #
      # Finds a summary matching the target and strategy. Marks it as outdated if the strategy found newer content
      def existing_summary
        if !defined?(@existing_summary)
          summary = AiSummary.find_by(target: strategy.target, summary_type: strategy.type)

          if summary
            @existing_summary = summary

            if summary.original_content_sha != latest_sha ||
                 content_to_summarize.any? { |cts| cts[:last_version_at] > summary.updated_at }
              summary.mark_as_outdated
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
        bot.llm.llm_model
      end

      def content_to_summarize
        @targets_data ||= strategy.targets_data
      end

      def latest_sha
        @latest_sha ||= AiSummary.build_sha(content_to_summarize.map { |c| c[:id] }.join)
      end

      # @param items { Array<Hash> } - Content to summarize. Structure will be: { poster: who wrote the content, id: a way to order content, text: content }
      # @param summary { String } - Intermediate summaries that we'll keep extending as part of our "folding" algorithm.
      # @param cursor { Integer } - Idx to know how much we already summarized.
      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
      #
      # The summarization algorithm.
      # The idea is to build an initial summary packing as much content as we can. Once we have the initial summary, we'll keep extending using the leftover
      # content until there is nothing left.
      #
      # @returns { String } - Resulting summary.
      def fold(items, summary, cursor, user, &on_partial_blk)
        tokenizer = llm_model.tokenizer_class
        tokens_left = available_tokens - tokenizer.size(summary)
        iteration_content = []

        items.each_with_index do |item, idx|
          next if idx < cursor

          as_text = "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "

          if tokenizer.below_limit?(as_text, tokens_left)
            iteration_content << item
            tokens_left -= tokenizer.size(as_text)
            cursor += 1
          else
            break
          end
        end

        context =
          DiscourseAi::Personas::BotContext.new(
            user: user,
            skip_tool_details: true,
            feature_name: strategy.feature,
            resource_url: "#{Discourse.base_path}/t/-/#{strategy.target.id}",
          )

        context.messages =
          (
            if summary.blank?
              strategy.first_summary_messages(iteration_content)
            else
              strategy.summary_extension_messages(summary, iteration_content)
            end
          )

        latest_summary = +""
        buffer_blk =
          Proc.new do |partial, cancel, placeholder, type|
            if type.blank?
              latest_summary << partial
              on_partial_blk.call(partial, cancel) if on_partial_blk
            end
          end

        if cursor == items.length
          bot.reply(context, &buffer_blk)

          latest_summary
        else
          bot.reply(context, llm_args: { max_tokens: 600 }, &buffer_blk)

          # Send original blk here for expansion.
          fold(items, latest_summary, cursor, user, &on_partial_blk)
        end
      end

      def available_tokens
        # Reserve tokens for the response and the base prompt
        # ~500 words
        reserved_tokens = 700

        llm_model.max_prompt_tokens - reserved_tokens
      end

      def truncate(item)
        item_content = item[:text].to_s
        split_1, split_2 =
          [item_content[0, item_content.size / 2], item_content[(item_content.size / 2)..-1]]

        truncation_length = 500
        tokenizer = llm_model.tokenizer_class

        item[:text] = [
          tokenizer.truncate(split_1, truncation_length),
          tokenizer.truncate(split_2.reverse, truncation_length).reverse,
        ].join(" ")

        item
      end

      def text_only_update(&on_partial_blk)
        Proc.new do |partial, cancel, placeholder, type|
          on_partial_blk.call(partial, cancel) if type.blank?
        end
      end
    end
  end
end
