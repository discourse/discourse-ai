# frozen_string_literal: true

module DiscourseAi
  module Automation
    class ReportRunner
      def self.default_instructions
        # not localizing for now cause non English LLM will require
        # a fair bit of experimentation
        <<~TEXT
        Generate report:

        ## Report Guidelines:

        - Length & Style: Aim for 12 dense paragraphs in a narrative style, focusing on internal forum discussions.
        - Accuracy: Only include verified information with no embellishments.
        - Sourcing: ALWAYS Back statements with links to forum discussions.
        - Markdown Usage: Enhance readability with **bold**, *italic*, and > quotes.
        - Linking: Use `#{Discourse.base_url}/t/-/TOPIC_ID/POST_NUMBER` for direct references.
        - User Mentions: Reference users with @USERNAME
        - Context tips: Staff are denoted with Username *. For example: jane * means that jane is a staff member. Do not render the * in the report.
        - Add many topic links: strive to link to at least 30 topics in the report. Topic Id is meaningless to end users if you need to throw in a link use [ref](...) or better still just embed it into the [sentence](...)
        - Categories and tags: use the format #TAG and #CATEGORY to denote tags and categories
        - When rendering staff highlights always link to referenced posts

        ## Structure:

        - Key statistics: Specify date range, call out important stats like number of new topics and posts
        - Overview: Briefly state trends within period.
        - General trends (popular categories and tags)
        - Highlighted content: 5 paragaraphs highlighting important topics people should know about. If possible have each paragraph link to multiple related topics.
        - Key insights and trends linking to a selection of posts that back them
        - Staff highlights linking to a selection of posts staff made
        TEXT
      end

      def self.run(
        sender_username:,
        receiver_username:,
        title:,
        model:,
        category_id: nil,
        tags: nil,
        allow_secure_categories: false
      )
      end
    end
  end
end
