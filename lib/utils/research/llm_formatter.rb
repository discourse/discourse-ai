# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class LlmFormatter
        attr_reader :processed_count, :total_count, :filter

        def initialize(filter, goal, llm, max_tokens = nil)
          @filter = filter
          @goal = goal
          @llm = llm
          @max_tokens = max_tokens || calculate_default_max_tokens(llm)
          @processed_count = 0
          @total_count = 0
        end

        def format_and_yield(results, &block)
          @total_count = results[:total] if results[:total]

          if results[:rows].nil? || results[:rows].empty?
            yield format_empty_result
            return
          end

          # For summarization or analysis goals
          if analysis_goal?
            yield format_analysis_result(results[:rows])
            return
          end

          # For standard listing with potential chunking
          formatted_results = format_standard_result(results[:rows])
          @processed_count += results[:rows].length

          if block_given?
            yield formatted_results
          else
            formatted_results
          end
        end

        def format_progress
          {
            processed: @processed_count,
            total: @total_count,
            filter: @filter.raw_filter,
            goal: @goal,
            percent_complete: @total_count > 0 ? (@processed_count.to_f / @total_count * 100).round(1) : 0
          }
        end

        private

        def analysis_goal?
          @goal.to_s.downcase.match?(/(summarize|analyze|extract|identify pattern|trend|insight)/)
        end

        def format_empty_result
          {
            message: "No results found for the given filter criteria",
            filter: @filter.raw_filter,
            goal: @goal
          }
        end

        def format_standard_result(rows)
          formatted_rows = rows.map do |row|
            {
              title: row[:title],
              excerpt: truncate_text(row[:excerpt] || ""),
              url: row[:url],
              author: row[:username],
              date: row[:created_at],
              likes: row[:like_count],
              replies: row[:reply_count]
            }
          end

          {
            goal: @goal,
            filter: @filter.raw_filter,
            count: formatted_rows.length,
            total: @total_count,
            offset: @filter.current_offset - formatted_rows.length,
            rows: formatted_rows
          }
        end

        def format_analysis_result(rows)
          # Group by relevant attributes based on goal
          data_points = extract_data_points(rows)

          {
            goal: @goal,
            filter: @filter.raw_filter,
            count: rows.length,
            total: @total_count,
            analysis: {
              sample_size: rows.length,
              data_points: data_points,
              time_range: extract_time_range(rows)
            }
          }
        end

        def extract_data_points(rows)
          # This would extract relevant data based on the goal
          # Simplified implementation for now
          {
            authors: rows.map { |r| r[:username] }.uniq.count,
            categories: rows.map { |r| r[:category_name] }.uniq.count,
            earliest_post: rows.map { |r| r[:created_at] }.min,
            latest_post: rows.map { |r| r[:created_at] }.max,
            avg_likes: (rows.sum { |r| r[:like_count].to_i } / [rows.length, 1].max.to_f).round(1)
          }
        end

        def extract_time_range(rows)
          dates = rows.map { |r| r[:created_at] }.compact
          return nil if dates.empty?

          {
            earliest: dates.min,
            latest: dates.max,
            span_days: ((dates.max - dates.min) / 86400).to_i rescue nil
          }
        end

        def truncate_text(text, max_length = 300)
          return text if text.length <= max_length
          text[0...max_length] + "..."
        end

        def calculate_default_max_tokens(llm)
          # Use a percentage of available tokens for results
          max_prompt_tokens = llm.max_prompt_tokens

          if max_prompt_tokens > 30_000
            max_prompt_tokens * 0.7
          elsif max_prompt_tokens > 10_000
            max_prompt_tokens * 0.6
          else
            max_prompt_tokens * 0.5
          end.to_i
        end
      end
    end
  end
end
