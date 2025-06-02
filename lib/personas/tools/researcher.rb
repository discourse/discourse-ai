# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Researcher < Tool
        attr_reader :filter, :result_count, :goals, :dry_run

        class << self
          def signature
            {
              name: name,
              description:
                "Analyze and extract information from content across the forum based on specified filters",
              parameters: [
                { name: "filter", description: filter_description, type: "string" },
                {
                  name: "goals",
                  description:
                    "The specific information you want to extract or analyze from the filtered content, you may specify multiple goals",
                  type: "string",
                },
                {
                  name: "dry_run",
                  description: "When true, only count matching posts without processing data",
                  type: "boolean",
                },
              ],
            }
          end

          def filter_description
            <<~TEXT
              Filter string to target specific content.
              - Supports user (@username)
              - date ranges (after:YYYY-MM-DD, before:YYYY-MM-DD for posts; topic_after:YYYY-MM-DD, topic_before:YYYY-MM-DD for topics)
              - categories (category:category1,category2)
              - tags (tag:tag1,tag2)
              - groups (group:group1,group2).
              - status (status:open, status:closed, status:archived, status:noreplies, status:single_user)
              - keywords (keywords:keyword1,keyword2) - specific words to search for in posts
              - max_results (max_results:10) the maximum number of results to return (optional)
              - order (order:latest, order:oldest, order:latest_topic, order:oldest_topic) - the order of the results (optional)
              - topic (topic:topic_id1,topic_id2) - add specific topics to the filter, topics will unconditionally be included

              If multiple tags or categories are specified, they are treated as OR conditions.

              Multiple filters can be combined with spaces. Example: '@sam after:2023-01-01 tag:feature'
            TEXT
          end

          def name
            "researcher"
          end

          def accepted_options
            [
              option(:max_results, type: :integer),
              option(:include_private, type: :boolean),
              option(:max_tokens_per_post, type: :integer),
            ]
          end
        end

        def invoke(&blk)
          max_results = options[:max_results] || 1000

          @filter = parameters[:filter] || ""
          @goals = parameters[:goals] || ""
          @dry_run = parameters[:dry_run].nil? ? false : parameters[:dry_run]

          post = Post.find_by(id: context.post_id)
          goals = parameters[:goals] || ""
          dry_run = parameters[:dry_run].nil? ? false : parameters[:dry_run]

          return { error: "No goals provided" } if goals.blank?
          return { error: "No filter provided" } if @filter.blank?

          guardian = nil
          guardian = Guardian.new(context.user) if options[:include_private]

          filter =
            DiscourseAi::Utils::Research::Filter.new(
              @filter,
              limit: max_results,
              guardian: guardian,
            )

          if filter.invalid_filters.present?
            return(
              {
                error:
                  "Invalid filter fragment: #{filter.invalid_filters.join(" ")}\n\n#{self.class.filter_description}",
              }
            )
          end

          @result_count = filter.search.count

          blk.call details

          if dry_run
            { dry_run: true, goals: goals, filter: @filter, number_of_posts: @result_count }
          else
            process_filter(filter, goals, post, &blk)
          end
        end

        def details
          if @dry_run
            I18n.t("discourse_ai.ai_bot.tool_description.researcher_dry_run", description_args)
          else
            I18n.t("discourse_ai.ai_bot.tool_description.researcher", description_args)
          end
        end

        def summary
          if @dry_run
            I18n.t("discourse_ai.ai_bot.tool_summary.researcher_dry_run")
          else
            I18n.t("discourse_ai.ai_bot.tool_summary.researcher")
          end
        end

        def description_args
          { count: @result_count || 0, filter: @filter || "", goals: @goals || "" }
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
              max_tokens_per_post: options[:max_tokens_per_post] || 2000,
            )

          results = []

          formatter.each_chunk { |chunk| results << run_inference(chunk[:text], goals, post, &blk) }

          if this.context.cancel_manager&.cancelled?
            {
              dry_run: false,
              goals: goals,
              filter: @filter,
              results: "Cancelled by user",
              cancelled_by_user: true,
            }
          else
            { dry_run: false, goals: goals, filter: @filter, results: results }
          end
        end

        def run_inference(chunk_text, goals, post, &blk)
          return if context.cancel_manager&.cancelled?

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

          @progress_dots ||= 0
          @progress_dots += 1
          blk.call(details + "\n\n#{"." * @progress_dots}")
          results.join
        end

        def goal_system_prompt(goals)
          <<~TEXT
            You are a researcher tool designed to analyze and extract information from forum content on #{Discourse.base_url}.
            The current date is #{::Time.zone.now.strftime("%a, %d %b %Y %H:%M %Z")}.
            Your task is to process the provided content and extract relevant information based on the specified goal.
            When extracting content ALWAYS include the following:
             - Multiple citations using Markdown
               - Topic citations: Interesting fact [ref](/t/-/TOPIC_ID)
               - Post citations: Interesting fact [ref](/t/-/TOPIC_ID/POST_NUMBER)
             - Relevent quotes from the direct source content
             - Relevant dates and times from the content

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
      end
    end
  end
end
