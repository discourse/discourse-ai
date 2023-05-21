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
          Discourse search supports, the following special commands:

          in:tagged: has at least 1 tag
          in:untagged: has no tags
          status:open: not closed or archived
          status:closed: closed
          status:public: topics that are not read restricted (eg: belong to a secure category)
          status:archived: archived
          status:noreplies: post count is 1
          status:single_user: only a single user posted on the topic
          post_count:X: only topics with X amount of posts
          min_posts:X: topics containing a minimum of X posts
          max_posts:X: topics with no more than max posts
          in:pinned: in all pinned topics (either global or per category pins)
          created:@USERNAME: topics created by a specific user
          category:bug: topics in the bug category AND all subcategories
          category:=bug: topics in the bug category excluding subcategories
          #=bug: same as above (no sub categories)
          #SLUG: try category first, then tag, then tag group
          #SLUG:SLUG: used for subcategory search to disambiguate
          min_views:100: topics containing 100 views or more
          max_views:100: topics containing 100 views or less
          tags:bug+feature: tagged both bug and feature
          tags:bug,feature: tagged either bug or feature
          -tags:bug+feature: excluding topics tagged bug and feature
          -tags:bug,feature: excluding topics tagged bug or feature
          l: order by post creation desc
          order:latest: order by post creation desc
          order:latest_topic: order by topic creation desc
          order:views: order by topic views desc
          order:likes: order by post like count - most liked posts first

          Keep in mind, search on Discourse uses AND to and terms.
          Strip the query down to the most important terms.
          Remove all stop words.
          Cast a wide net instead of trying to be over specific.
          Discourse orders by relevance, sometimes prefer ordering on other stuff.

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
        Search.execute(search_string.to_s, search_type: :full_page, guardian: Guardian.new())

      posts = results.posts
      posts = posts[0..limit - 1] if limit

      @last_num_results = results.posts.length

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
