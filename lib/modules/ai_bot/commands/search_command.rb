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
      @last_query = search_string
      results =
        Search.execute(search_string.to_s, search_type: :full_page, guardian: Guardian.new())

      @last_num_results = results.posts.length

      results.posts[0..10]
        .map do |p|
          {
            title: p.topic.title,
            url: p.url,
            raw_truncated: p.raw[0..250],
            excerpt: p.excerpt,
            created: p.created_at,
          }
        end
        .to_json
    end
  end
end
