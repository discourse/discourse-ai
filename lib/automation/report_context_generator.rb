# frozen_string_literal: true

module DiscourseAi
  module Automation
    class ReportContextGenerator
      def self.generate(
        start_date:,
        duration:,
        category_ids: nil,
        tags: nil,
        allow_secure_categories: false,
        max_posts: 100,
        excerpt_length: 600,
        prioritized_group_ids: nil
      )
        new(
          start_date: start_date,
          duration: duration,
          category_ids: category_ids,
          tags: tags,
          allow_secure_categories: allow_secure_categories,
          max_posts: max_posts,
          excerpt_length: excerpt_length,
          prioritized_group_ids: prioritized_group_ids,
        ).generate
      end

      def initialize(
        start_date:,
        duration:,
        category_ids:,
        tags:,
        allow_secure_categories:,
        max_posts:,
        excerpt_length:,
        prioritized_group_ids:
      )
        @start_date = start_date
        @duration = duration
        @category_ids = category_ids
        @tags = tags
        @allow_secure_categories = allow_secure_categories
        @max_posts = max_posts
        @excerpt_length = excerpt_length
        @prioritized_group_ids = prioritized_group_ids

        @posts =
          Post
            .where("posts.created_at >= ?", @start_date)
            .joins(topic: :category)
            .includes(:topic, :user)
            .where("posts.created_at < ?", @start_date + @duration)
            .where("posts.post_type = ?", Post.types[:regular])
            .where("posts.hidden_at IS NULL")
            .where("topics.deleted_at IS NULL")
            .where("topics.archetype = ?", Archetype.default)
        @posts = @posts.where("categories.read_restricted = ?", false) if !@allow_secure_categories
        @posts = @posts.where("categories.id IN (?)", @category_ids) if @category_ids.present?

        if @tags.present?
          tag_ids = Tag.where(name: @tags).select(:id)
          topic_ids_with_tags = TopicTag.where(tag_id: tag_ids).select(:topic_id)
          @posts = @posts.where(topic_id: topic_ids_with_tags)
        end

        @group_user_ids = Set.new(GroupUser.where(group_id: @prioritized_group_ids).pluck(:user_id))
      end

      def format_topic(topic)
        info = []
        info << ""
        info << "### #{topic.title}"
        info << "topic_id: #{topic.id}"
        info << "category: #{topic.category&.name}"
        info << "likes: #{topic.like_count}"
        tags = topic.tags.pluck(:name)
        info << "tags: #{topic.tags.pluck(:name).join(", ")}" if tags.present?
        info << topic.created_at.strftime("%Y-%m-%d %H:%M")
        { created_at: topic.created_at, info: info.join("\n"), posts: {} }
      end

      def format_post(post)
        buffer = []
        buffer << ""
        buffer << "post_number: #{post.post_number}"
        buffer << post.created_at.strftime("%Y-%m-%d %H:%M")
        buffer << "user: #{post.user&.username} #{" *" if @group_user_ids.include? post.user_id}"
        buffer << "likes: #{post.like_count}"
        excerpt = post.raw[0..@excerpt_length]
        excerpt = "excerpt: #{excerpt}..." if excerpt.length < post.raw.length
        buffer << "#{excerpt}"
        buffer.join("\n")
        { likes: post.like_count, info: buffer.join("\n") }
      end

      def format_summary
        topic_count =
          @posts
            .where("topics.created_at > ?", @start_date)
            .select(:topic_id)
            .distinct(:topic_id)
            .count

        buffer = []
        buffer << "Start Date: #{@start_date.to_date}"
        buffer << "End Date: #{(@start_date + @duration).to_date}"
        buffer << "New posts: #{@posts.count}"
        buffer << "New topics: #{topic_count}"
        buffer.join("\n")
      end

      def format_topics
        buffer = []
        topics = {}

        post_count = 0

        @posts = @posts.order("posts.like_count desc, posts.created_at desc")

        if @prioritized_group_ids.present?
          user_groups = GroupUser.where(group_id: @prioritized_group_ids)
          prioritized_posts = @posts.where(user_id: user_groups.select(:user_id)).limit(@max_posts)

          post_count += add_posts(prioritized_posts, topics)
        end

        add_posts(@posts.limit(@max_posts), topics, limit: @max_posts - post_count)

        # we need last posts in all topics
        # they may have important info
        last_posts =
          @posts.where("posts.post_number = topics.highest_post_number").where(
            "topics.id IN (?)",
            topics.keys,
          )

        add_posts(last_posts, topics)

        topics.each do |topic_id, topic_info|
          topic_info[:post_likes] = topic_info[:posts].sum { |_, post_info| post_info[:likes] }
        end

        topics = topics.sort { |a, b| b[1][:post_likes] <=> a[1][:post_likes] }

        topics.each do |topic_id, topic_info|
          buffer << topic_info[:info]

          last_post_number = 0

          topic_info[:posts]
            .sort { |a, b| a[0] <=> b[0] }
            .each do |post_number, post_info|
              buffer << "\n..." if post_number > last_post_number + 1
              buffer << post_info[:info]
              last_post_number = post_number
            end
        end

        buffer.join("\n")
      end

      def generate
        buffer = []

        buffer << "## Summary"
        buffer << format_summary
        buffer << "\n## Topics"
        buffer << format_topics

        buffer.join("\n")
      end

      def add_posts(relation, topics, limit: nil)
        post_count = 0
        relation.each do |post|
          topics[post.topic_id] ||= format_topic(post.topic)
          if !topics[post.topic_id][:posts][post.post_number]
            topics[post.topic_id][:posts][post.post_number] = format_post(post)
            post_count += 1
            limit -= 1 if limit
          end
          break if limit && limit <= 0
        end
        post_count
      end
    end
  end
end

system_prompt = "You are a helpful bot"

context =
  DiscourseAi::Automation::ReportContextGenerator.generate(
    start_date: 7.days.ago,
    duration: 7.days,
    max_posts: 400,
    prioritized_group_ids: [45],
  )

instruction = <<INST
Generate report for Open AI executives

## Report Guidelines:

- Length & Style: Aim for 12 dense paragraphs in a narrative style, focusing on internal forum discussions.
- Accuracy: Only include verified information with no embellishments.
- Sourcing: ALWAYS Back statements with links to forum discussions.
- Markdown Usage: Enhance readability with **bold**, *italic*, and > quotes.
- Linking: Use `https://community.openai.com/t/-/TOPIC_ID/POST_NUMBER` for direct references.
- User Mentions: Reference users with @USERNAME
- Context tips: Open AI staff are denoted with Username *. For example: jane * means that jane is Open AI staff. Do not render the * in the report.
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

INST

prompt = <<~PROMPT

#{instruction}

CONTEXT
{{{
#{context}
}}}

#{instruction}

PROMPT

messages = [{ role: :system, content: system_prompt }, { role: :user, content: prompt }]

puts DiscourseAi::Tokenizer::OpenAiTokenizer.tokenize(prompt).length
puts "-" * 80

DiscourseAi::Inference::OpenAiCompletions.perform!(
  messages,
  "gpt-4-1106-preview",
  temperature: 0,
  max_tokens: 4000,
) { |partial| print partial.dig(:choices, 0, :delta, :content) }

puts "-" * 80

exit
