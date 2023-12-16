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

      def self.run!(**args)
        new(**args).run!
      end

      def initialize(
        sender_username:,
        receivers:,
        title:,
        model:,
        category_ids:,
        tags:,
        allow_secure_categories:,
        debug_mode:,
        sample_size:,
        instructions:
      )
        @sender = User.find_by(username: sender_username)
        @receivers = User.where(username: receivers)
        @title = title

        @llm = DiscourseAi::Completions::Llm.proxy(model)
        @category_ids = category_ids
        @tags = tags
        @allow_secure_categories = allow_secure_categories
        @debug_mode = debug_mode
        @sample_size = sample_size.to_i < 10 ? 10 : sample_size.to_i
        @instructions = instructions
      end

      def run!
        context =
          DiscourseAi::Automation::ReportContextGenerator.generate(
            start_date: 7.days.ago,
            duration: 7.days,
            max_posts: @sample_size,
          )
        input = <<~INPUT
          #{@instructions}

          <context>
          #{context}
          </context>

          #{@instructions}
        INPUT

        prompt = {
          insts: "You are a helpful bot specializing in summarizing activity Discourse sites",
          input: input,
        }

        result = +""

        puts if Rails.env.development? && @debug_mode

        @llm.completion!(prompt, Discourse.system_user) do |response|
          print response if Rails.env.development? && @debug_mode
          result << response
        end

        post =
          PostCreator.create!(
            @sender,
            raw: result,
            title: @title,
            archetype: Archetype.private_message,
            target_usernames: @receivers.map(&:username).join(","),
            skip_validations: true,
          )

        if @debug_mode
          PostCreator.create!(
            @sender,
            raw: "LLM input was:\n\n#{input}",
            topic_id: post.topic_id,
            skip_validations: true,
          )
        end
      end
    end
  end
end
