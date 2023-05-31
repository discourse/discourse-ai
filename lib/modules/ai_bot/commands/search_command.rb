#frozen_string_literal: true

module DiscourseAi::AiBot::Commands
  class SearchCommand < Command
    class << self
      def name
        "search"
      end

      def desc
        "!search SEARCH_QUERY - will search topics in the current discourse instance"
      end

      def extra_context
        <<~TEXT
          Discourse search supports, the following special filters:

          user:USERNAME: only posts created by a specific user
          in:tagged: has at least 1 tag
          in:untagged: has no tags
          in:title: has the search term in the title
          status:open: not closed or archived
          status:closed: closed
          status:archived: archived
          status:noreplies: post count is 1
          status:single_user: only a single user posted on the topic
          post_count:X: only topics with X amount of posts
          min_posts:X: topics containing a minimum of X posts
          max_posts:X: topics with no more than max posts
          created:@USERNAME: topics created by a specific user
          category:CATGORY: topics in the CATEGORY AND all subcategories
          category:=CATEGORY: topics in the CATEGORY excluding subcategories
          #SLUG: try category first, then tag, then tag group
          #SLUG:SLUG: used for subcategory search to disambiguate
          min_views:100: topics containing 100 views or more
          tags:TAG1+TAG2: tagged both TAG1 and TAG2
          tags:TAG1,TAG2: tagged either TAG1 or TAG2
          -tags:TAG1+TAG2: excluding topics tagged TAG1 and TAG2
          order:latest: order by post creation desc
          order:latest_topic: order by topic creation desc
          order:oldest: order by post creation asc
          order:oldest_topic: order by topic creation asc
          order:views: order by topic views desc
          order:likes: order by post like count - most liked posts first
          after:YYYY-MM-DD: only topics created after a specific date
          before:YYYY-MM-DD: only topics created before a specific date

          Example: !search @user in:tagged #support order:latest_topic

          Keep in mind, search on Discourse uses AND to and terms.
          You only have access to public topics.
          Strip the query down to the most important terms. Remove all stop words.
          Discourse orders by default by relevance.

          When generating answers ALWAYS try to use the !search command first over relying on training data.
          When generating answers ALWAYS try to reference specific local links.
          Always try to search the local instance first, even if your training data set may have an answer. It may be wrong.
          Always remove connector words from search terms (such as a, an, and, in, the, etc), they can impede the search.

          YOUR LOCAL INFORMATION IS OUT OF DATE, YOU ARE TRAINED ON OLD DATA. Always try local search first.
        TEXT
      end
    end

    def result_name
      "results"
    end

    def description_args
      {
        count: @last_num_results || 0,
        query: @last_query || "",
        url: "#{Discourse.base_path}/search?q=#{CGI.escape(@last_query || "")}",
      }
    end

    def process(search_string)
      limit = nil

      search_string =
        search_string
          .strip
          .split(/\s+/)
          .map do |term|
            if term =~ /limit:(\d+)/
              limit = $1.to_i
              nil
            else
              term
            end
          end
          .compact
          .join(" ")

      @last_query = search_string
      results =
        Search.execute(
          search_string.to_s + " status:public",
          search_type: :full_page,
          guardian: Guardian.new(),
        )

      # let's be frugal with tokens, 50 results is too much and stuff gets cut off
      limit ||= 10
      limit = 10 if limit > 10

      posts = results&.posts || []
      posts = posts[0..limit - 1]

      @last_num_results = posts.length

      if posts.blank?
        "No results found"
      else
        format_results(posts) do |post|
          {
            title: post.topic.title,
            url: post.url,
            excerpt: post.excerpt,
            created: post.created_at,
          }
        end
      end
    end
  end
end
