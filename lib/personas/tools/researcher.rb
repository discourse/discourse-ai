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
                  name: "goals",
                  description:
                    "The specific information you want to extract or analyze from the filtered content, you may specify multiple goals",
                  type: "string",
                },
                {
                  name: "dry_run",
                  description: "When true, only count matching items without processing data",
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

        def invoke(&blk)
          @last_filter = parameters[:filter] || ""
          post = Post.find_by(id: context.post_id)
          goals = parameters[:goals] || ""
          dry_run = parameters[:dry_run].nil? ? false : parameters[:dry_run]

          return { error: "No goals provided" } if goals.blank?
          return { error: "No filter provided" } if @last_filter.blank?

          filter = DiscourseAi::Utils::Research::Filter.new(@last_filter)

          @result_count = filter.search.count

          if dry_run
            { dry_run: true, goals: goals, filter: @last_filter, number_of_results: @result_count }
          else
            process_filter(filter, goals, post, &blk)
          end
        end

        protected

        MIN_TOKENS_FOR_RESEARCH = 8000
        def process_filter(filter, goals, post, &blk)
          if llm.max_prompt_tokens < MIN_TOKENS_FOR_RESEARCH
            raise ArgumentError,
                  "LLM max tokens too low for research. Minimum is #{MIN_TOKENS_FOR_RESEARCH}."
          end
          formatter =
            DiscourseAi::Utils::Research::LlmFormatter.new(
              filter,
              max_tokens_per_batch: llm.max_prompt_tokens - 2000,
              tokenizer: llm.tokenizer,
            )

          results = []

          formatter.each_chunk { |chunk| results << run_inference(chunk[:text], goals, post, &blk) }
          { dry_run: false, goals: goals, filter: @last_filter, results: results }
        end

        def run_inference(chunk_text, goals, post, &blk)
          system_prompt = goal_system_prompt(goals)
          user_prompt = goal_user_prompt(goals, chunk_text)

          prompt =
            DiscourseAi::Completions::Prompt.new(
              system_prompt,
              messages: [{ type: :user, content: user_prompt }],
              post_id: post.id,
              topic_id: post.topic_id,
            )

          results = []
          llm.generate(
            prompt,
            user: post.user,
            feature_name: context.feature_name,
            cancel_manager: context.cancel_manager,
          ) { |partial| results << partial }

          blk.call(".")
          results.join
        end

        def goal_system_prompt(goals)
          <<~TEXT
            You are a researcher tool designed to analyze and extract information from forum content.
            Your task is to process the provided content and extract relevant information based on the specified goal.

            Your goal is: #{goals}
          TEXT
        end

        def goal_user_prompt(goals, chunk_text)
          <<~TEXT
            Here is the content to analyze:

            {{{
            #{chunk_text}
            }}}

            Your goal is: #{goals}
           TEXT
        end

        def description_args
          { count: @result_count || 0, filter: @last_filter || "" }
        end

        private

        def simulate_count(filter_components)
          # In a real implementation, this would query the database to get a count
          # For now, return a simulated count
          rand(10..100)
        end

        def perform_research(filter_components, goals, max_results)
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
