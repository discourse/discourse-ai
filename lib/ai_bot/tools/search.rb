#frozen_string_literal: true

module DiscourseAi
  module AiBot
    module Tools
      class Search < Tool
        MIN_SEMANTIC_RESULTS = 5

        class << self
          def signature
            {
              name: name,
              description:
                "Will search topics in the current discourse instance, when rendering always prefer to link to the topics you find",
              parameters: [
                {
                  name: "search_query",
                  description:
                    "Specific keywords to search for, space seperated (correct bad spelling, remove connector words)",
                  type: "string",
                },
                {
                  name: "user",
                  description:
                    "Filter search results to this username (only include if user explicitly asks to filter by user)",
                  type: "string",
                },
                {
                  name: "order",
                  description: "search result order",
                  type: "string",
                  enum: %w[latest latest_topic oldest views likes],
                },
                {
                  name: "limit",
                  description:
                    "limit number of results returned (generally prefer to just keep to default)",
                  type: "integer",
                },
                {
                  name: "max_posts",
                  description:
                    "maximum number of posts on the topics (topics where lots of people posted)",
                  type: "integer",
                },
                {
                  name: "tags",
                  description:
                    "list of tags to search for. Use + to join with OR, use , to join with AND",
                  type: "string",
                },
                { name: "category", description: "category name to filter to", type: "string" },
                {
                  name: "before",
                  description: "only topics created before a specific date YYYY-MM-DD",
                  type: "string",
                },
                {
                  name: "after",
                  description: "only topics created after a specific date YYYY-MM-DD",
                  type: "string",
                },
                {
                  name: "status",
                  description: "search for topics in a particular state",
                  type: "string",
                  enum: %w[open closed archived noreplies single_user],
                },
              ],
            }
          end

          def name
            "search"
          end

          def custom_system_message
            <<~TEXT
            You were trained on OLD data, lean on search to get up to date information about this forum
            When searching try to SIMPLIFY search terms
            Discourse search joins all terms with AND. Reduce and simplify terms to find more results.
          TEXT
          end

          def accepted_options
            [option(:base_query, type: :string), option(:max_results, type: :integer)]
          end
        end

        def search_args
          parameters.slice(:user, :order, :max_posts, :tags, :before, :after, :status)
        end

        def invoke(bot_user, llm)
          search_string =
            search_args.reduce(+parameters[:search_query].to_s) do |memo, (key, value)|
              return memo if value.blank?
              memo << " " << "#{key}:#{value}"
            end

          @last_query = search_string

          yield(I18n.t("discourse_ai.ai_bot.searching", query: search_string))

          if options[:base_query].present?
            search_string = "#{search_string} #{options[:base_query]}"
          end

          results =
            ::Search.execute(
              search_string.to_s + " status:public",
              search_type: :full_page,
              guardian: Guardian.new(),
            )

          # let's be frugal with tokens, 50 results is too much and stuff gets cut off
          max_results = calculate_max_results(llm)
          results_limit = parameters[:limit] || max_results
          results_limit = max_results if parameters[:limit].to_i > max_results

          should_try_semantic_search =
            SiteSetting.ai_embeddings_semantic_search_enabled && results_limit == max_results &&
              parameters[:search_query].present?

          max_semantic_results = max_results / 4
          results_limit = results_limit - max_semantic_results if should_try_semantic_search

          posts = results&.posts || []
          posts = posts[0..results_limit - 1]

          if should_try_semantic_search
            semantic_search = DiscourseAi::Embeddings::SemanticSearch.new(Guardian.new())
            topic_ids = Set.new(posts.map(&:topic_id))

            search = ::Search.new(search_string, guardian: Guardian.new)

            results = nil
            begin
              results = semantic_search.search_for_topics(search.term)
            rescue => e
              Discourse.warn_exception(e, message: "Semantic search failed")
            end

            if results
              results = search.apply_filters(results)

              results.each do |post|
                next if topic_ids.include?(post.topic_id)

                topic_ids << post.topic_id
                posts << post

                break if posts.length >= max_results
              end
            end
          end

          @last_num_results = posts.length
          # this is the general pattern from core
          # if there are millions of hidden tags it may fail
          hidden_tags = nil

          if posts.blank?
            { args: parameters, rows: [], instruction: "nothing was found, expand your search" }
          else
            format_results(posts, args: parameters) do |post|
              category_names = [
                post.topic.category&.parent_category&.name,
                post.topic.category&.name,
              ].compact.join(" > ")
              row = {
                title: post.topic.title,
                url: Discourse.base_path + post.url,
                username: post.user&.username,
                excerpt: post.excerpt,
                created: post.created_at,
                category: category_names,
                likes: post.like_count,
                topic_views: post.topic.views,
                topic_likes: post.topic.like_count,
                topic_replies: post.topic.posts_count - 1,
              }

              if SiteSetting.tagging_enabled
                hidden_tags ||= DiscourseTagging.hidden_tag_names
                # using map over pluck to avoid n+1 (assuming caller preloading)
                tags = post.topic.tags.map(&:name) - hidden_tags
                row[:tags] = tags.join(", ") if tags.present?
              end

              row
            end
          end
        end

        private

        def calculate_max_results(llm)
          max_results = options[:max_results].to_i
          return [max_results, 100].min if max_results > 0

          if llm.max_prompt_tokens > 30_000
            60
          elsif llm.max_prompt_tokens > 10_000
            40
          else
            20
          end
        end
      end
    end
  end
end
