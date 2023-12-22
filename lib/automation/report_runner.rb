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
        - Add many topic links: strive to link to at least 30 topics in the report. Topic Id is meaningless to end users if you need to throw in a link use [ref](...) or better still just embed it into the [sentence](...)
        - Categories and tags: use the format #TAG and #CATEGORY to denote tags and categories

        ## Structure:

        - Key statistics: Specify date range, call out important stats like number of new topics and posts
        - Overview: Briefly state trends within period.
        - Highlighted content: 5 paragaraphs highlighting important topics people should know about. If possible have each paragraph link to multiple related topics.
        - Key insights and trends linking to a selection of posts that back them
        TEXT
      end

      def self.run!(**args)
        new(**args).run!
      end

      def initialize(
        sender_username:,
        receivers:,
        topic_id:,
        title:,
        model:,
        category_ids:,
        tags:,
        allow_secure_categories:,
        debug_mode:,
        sample_size:,
        instructions:,
        days:,
        offset:,
        priority_group_id:,
        tokens_per_post:
      )
        @sender = User.find_by(username: sender_username)
        @receivers = User.where(username: receivers)
        @email_receivers = receivers&.filter { |r| r.include? "@" }
        @title =
          if title.present?
            title
          else
            I18n.t("discourse_automation.llm_report.title")
          end
        @model = model
        @llm = DiscourseAi::Completions::Llm.proxy(model)
        @category_ids = category_ids
        @tags = tags
        @allow_secure_categories = allow_secure_categories
        @debug_mode = debug_mode
        @sample_size = sample_size.to_i < 10 ? 10 : sample_size.to_i
        @instructions = instructions
        @days = days.to_i
        @offset = offset.to_i
        @priority_group_id = priority_group_id
        @tokens_per_post = tokens_per_post.to_i
        @topic_id = topic_id.presence&.to_i

        if !@topic_id && !@receivers.present? && !@email_receivers.present?
          raise ArgumentError, "Must specify topic_id or receivers"
        end
      end

      def run!
        start_date = (@offset + @days).days.ago
        end_date = start_date + @days.days

        title =
          @title.gsub(
            "%DATE%",
            start_date.strftime("%Y-%m-%d") + " - " + end_date.strftime("%Y-%m-%d"),
          )

        prioritized_group_ids = [@priority_group_id] if @priority_group_id.present?
        context =
          DiscourseAi::Automation::ReportContextGenerator.generate(
            start_date: start_date,
            duration: @days.days,
            max_posts: @sample_size,
            tags: @tags,
            category_ids: @category_ids,
            prioritized_group_ids: prioritized_group_ids,
            allow_secure_categories: @allow_secure_categories,
            tokens_per_post: @tokens_per_post,
            tokenizer: @llm.tokenizer,
          )
        input = <<~INPUT
          #{@instructions}

          <context>
          #{context}
          </context>

          #{@instructions}
        INPUT

        prompt = {
          insts: "You are a helpful bot specializing in summarizing activity on Discourse sites",
          input: input,
          final_insts: "Here is the report I generated for you",
          params: {
            @model => {
              temperature: 0,
            },
          },
        }

        result = +""

        puts if Rails.env.development? && @debug_mode

        @llm.completion!(prompt, Discourse.system_user) do |response|
          print response if Rails.env.development? && @debug_mode
          result << response
        end

        receiver_usernames = @receivers.map(&:username).join(",")

        if @topic_id
          PostCreator.create!(@sender, raw: result, topic_id: @topic_id, skip_validations: true)
          # no debug mode for topics, it is too noisy
        end

        if receiver_usernames.present?
          post =
            PostCreator.create!(
              @sender,
              raw: result,
              title: title,
              archetype: Archetype.private_message,
              target_usernames: receiver_usernames,
              skip_validations: true,
            )

          if @debug_mode
            input = input.split("\n").map { |line| "    #{line}" }.join("\n")
            raw = <<~RAW
            ```
            tokens: #{@llm.tokenizer.tokenize(input).length}
            start_date: #{start_date},
            duration: #{@days.days},
            max_posts: #{@sample_size},
            tags: #{@tags},
            category_ids: #{@category_ids},
            priority_group: #{@priority_group_id}
            LLM context was:
            ```

            #{input}
          RAW
            PostCreator.create!(@sender, raw: raw, topic_id: post.topic_id, skip_validations: true)
          end
        end

        if @email_receivers.present?
          @email_receivers.each do |to_address|
            Email::Sender.new(
              ::AiReportMailer.send_report(to_address, subject: title, body: result),
              :ai_report,
            ).send
          end
        end
      end
    end
  end
end
