# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Researcher < Tool
        attr_reader :last_filter, :result_count

        class << self
          def signature
            {
              name: name,
              description:
                "Analyze and extract information from content across the forum based on specified filters",
              parameters: [
                {
                  name: "filter",
                  description:
                    "Filter string to target specific content. Supports user (@username), date ranges (after:YYYY-MM-DD, before:YYYY-MM-DD), categories (category:name), tags (tag:name), groups (group:name). Multiple filters can be combined with spaces. Example: '@sam after:2023-01-01 tag:feature'",
                  type: "string",
                },
                {
                  name: "goal",
                  description:
                    "The specific information you want to extract or analyze from the filtered content",
                  type: "string",
                },
                {
                  name: "dry_run",
                  description:
                    "When true, only count matching items without processing data (default: true)",
                  type: "boolean",
                },
              ],
            }
          end

          def name
            "researcher"
          end

          def custom_system_message
            <<~TEXT
            Use the researcher tool to analyze patterns and extract insights from forum content.
            For complex research tasks, start with a dry run to gauge the scope before processing.
            TEXT
          end

          def accepted_options
            [option(:max_results, type: :integer), option(:include_private, type: :boolean)]
          end
        end

        def invoke
          @last_filter = parameters[:filter] || ""
          goal = parameters[:goal] || ""
          dry_run = parameters[:dry_run].nil? ? true : parameters[:dry_run]

          yield(I18n.t("discourse_ai.ai_bot.researching", filter: @last_filter, goal: goal))

          # Parse the filter string to extract components
          filter_components = parse_filter(@last_filter)

          # Determine max results
          max_results = calculate_max_results(llm)

          # In a real implementation, we would query the database here
          # For now, just simulate the behavior
          if dry_run
            @result_count = simulate_count(filter_components)
            { count: @result_count, filter: @last_filter, goal: goal, dry_run: true }
          else
            results = perform_research(filter_components, goal, max_results)
            @result_count = results[:rows]&.length || 0
            results
          end
        end

        protected

        def description_args
          { count: @result_count || 0, filter: @last_filter || "" }
        end

        private

        def parse_filter(filter_string)
          # This would parse the filter string into components
          # For example, extracting username, date ranges, categories, tags, etc.
          # Simplified implementation for now
          components = {}
          components[:raw] = filter_string
          components
        end

        def simulate_count(filter_components)
          # In a real implementation, this would query the database to get a count
          # For now, return a simulated count
          rand(10..100)
        end

        def perform_research(filter_components, goal, max_results)
          # This would perform the actual research based on the filter and goal
          # For now, return a simplified result structure
          format_results([], %w[content url author date])
        end

        def calculate_max_results(llm)
          max_results = options[:max_results].to_i
          return [max_results, 100].min if max_results > 0

          if llm.max_prompt_tokens > 30_000
            50
          elsif llm.max_prompt_tokens > 10_000
            30
          else
            15
          end
        end
      end
    end
  end
end
