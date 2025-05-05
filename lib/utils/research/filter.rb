# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class Filter
        attr_reader :raw_filter, :parsed_components, :current_offset, :batch_size

        VALID_FILTER_PATTERNS = {
          user: /\@(\w+)/,
          before: /before:(\d{4}-\d{2}-\d{2})/,
          after: /after:(\d{4}-\d{2}-\d{2})/,
          category: /category:([a-zA-Z0-9_\-]+)/,
          tag: /tag:([a-zA-Z0-9_\-]+)/,
          group: /group:([a-zA-Z0-9_\-]+)/,
          status: /status:(open|closed|archived|noreplies|single_user)/,
        }

        DEFAULT_BATCH_SIZE = 20

        def initialize(filter_string, batch_size: DEFAULT_BATCH_SIZE)
          @raw_filter = filter_string.to_s
          @batch_size = batch_size
          @current_offset = 0
          @parsed_components = parse_filter
        end

        def parse_filter
          components = {
            users: [],
            categories: [],
            tags: [],
            groups: [],
            date_range: {
            },
            status: nil,
            raw: @raw_filter,
          }

          # Extract user mentions
          @raw_filter
            .scan(VALID_FILTER_PATTERNS[:user])
            .each { |match| components[:users] << match[0] }

          # Extract date ranges
          if before_match = @raw_filter.match(VALID_FILTER_PATTERNS[:before])
            components[:date_range][:before] = before_match[1]
          end

          if after_match = @raw_filter.match(VALID_FILTER_PATTERNS[:after])
            components[:date_range][:after] = after_match[1]
          end

          # Extract categories
          @raw_filter
            .scan(VALID_FILTER_PATTERNS[:category])
            .each { |match| components[:categories] << match[0] }

          # Extract tags
          @raw_filter
            .scan(VALID_FILTER_PATTERNS[:tag])
            .each { |match| components[:tags] << match[0] }

          # Extract groups
          @raw_filter
            .scan(VALID_FILTER_PATTERNS[:group])
            .each { |match| components[:groups] << match[0] }

          # Extract status
          if status_match = @raw_filter.match(VALID_FILTER_PATTERNS[:status])
            components[:status] = status_match[1]
          end

          components
        end

        def next_batch
          previous_offset = @current_offset
          @current_offset += @batch_size
          previous_offset
        end

        def reset_batch
          @current_offset = 0
        end

        def to_query_params
          params = {}
          params[:username] = parsed_components[:users].first if parsed_components[:users].any?
          params[:before] = parsed_components[:date_range][:before] if parsed_components[
            :date_range
          ][
            :before
          ]
          params[:after] = parsed_components[:date_range][:after] if parsed_components[:date_range][
            :after
          ]
          params[:category] = parsed_components[:categories].first if parsed_components[
            :categories
          ].any?
          params[:tags] = parsed_components[:tags].join(",") if parsed_components[:tags].any?
          params[:status] = parsed_components[:status] if parsed_components[:status]
          params
        end
      end
    end
  end
end
