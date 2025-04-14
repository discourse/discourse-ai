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
        truncated_content = content_to_summarize.map { |cts| truncate(cts) }

        # Done here to cover non-streaming mode.
        json_reply_end = "\"}"
        summary = fold(truncated_content, user, &on_partial_blk).chomp(json_reply_end)

        if persist_summaries
          AiSummary.store!(strategy, llm_model, summary, truncated_content, human: user&.human?)
        else
          AiSummary.new(summarized_text: summary)
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
      # @param user { User } - User object used for auditing usage.
      # @param &on_partial_blk { Block - Optional } - The passed block will get called with the LLM partial response alongside a cancel function.
      # Note: The block is only called with results of the final summary, not intermediate summaries.
      #
      # The summarization algorithm.
      # It will summarize as much content summarize given the model's context window. If will prioriotize newer content in case it doesn't fit.
      #
      # @returns { String } - Resulting summary.
      def fold(items, user, &on_partial_blk)
        tokenizer = llm_model.tokenizer_class
        tokens_left = available_tokens
        content_in_window = []

        items.each_with_index do |item, idx|
          as_text = "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "

          if tokenizer.below_limit?(as_text, tokens_left)
            content_in_window << item
            tokens_left -= tokenizer.size(as_text)
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
            messages: strategy.as_llm_messages(content_in_window),
          )

        summary = +""

        # Auxiliary variables to get the summary content from the JSON response.
        json_start_buffer = +""
        json_start_found = false
        # { is optional because Claude uses prefill, so it's not incldued.
        # TODO(roman): Maybe extraction should happen in the bot?
        json_summary_schema_keys = bot.persona.response_format&.first.to_h
        json_reply_start_regex = /\{?\s*"#{json_summary_schema_keys[:key]}"\s*:\s*"/
        # We need to buffer escaped newlines as the API likes to send \\ and n in different chunks.
        partial_unescape_buffer = +""
        unescape_regex = %r{\\(["/bfnrt])}
        json_reply_end = "\"}"

        buffer_blk =
          Proc.new do |partial, cancel, _, type|
            if type.blank?
              if bot.returns_json?
                # Extract summary from JSON.
                if json_start_found
                  if partial.end_with?("\\")
                    partial_unescape_buffer << partial
                  else
                    unescaped_partial = partial_unescape_buffer

                    buffered_newline = !partial_unescape_buffer.empty? && partial.first == "n"
                    if buffered_newline
                      unescaped_partial << partial.first

                      unescaped_partial = unescaped_partial.gsub("\\n", "\n")
                      unescaped_partial << partial[1..].to_s
                    else
                      unescaped_partial << partial.gsub("\\n", "\n")
                    end
                    partial_unescape_buffer = +""

                    summary << unescaped_partial

                    on_partial_blk.call(unescaped_partial, cancel) if on_partial_blk
                  end
                else
                  json_start_buffer << partial

                  if json_start_buffer.match?(json_reply_start_regex)
                    buffered_start = json_start_buffer.gsub(json_reply_start_regex, "")
                    summary << buffered_start

                    on_partial_blk.call(buffered_start, cancel) if on_partial_blk

                    json_start_found = true
                  end
                end
              else
                # Assume response is a regular completion.
                summary << partial
                on_partial_blk.call(partial, cancel) if on_partial_blk
              end
            end
          end

        bot.reply(context, &buffer_blk)

        summary.chomp(json_reply_end)
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
    end
  end
end
