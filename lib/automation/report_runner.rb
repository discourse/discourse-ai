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
        - Highlighted content: 5 paragraphs highlighting important topics people should know about. If possible have each paragraph link to multiple related topics.
        - Key insights and trends linking to a selection of posts that back them
        TEXT
      end

      def self.run!(**args)
        new(**args).run!
      end

      def initialize(
        sender_username:,
        model:,
        sample_size:,
        instructions:,
        tokens_per_post:,
        days:,
        offset:,
        receivers: nil,
        topic_id: nil,
        title: nil,
        category_ids: nil,
        tags: nil,
        priority_group_id: nil,
        allow_secure_categories: false,
        debug_mode: false,
        exclude_category_ids: nil,
        exclude_tags: nil,
        top_p: 0.1,
        temperature: 0.2,
        suppress_notifications: false
      )
        @sender = User.find_by(username: sender_username)
        @receivers = User.where(username: receivers)
        @email_receivers = receivers&.filter { |r| r.include? "@" }
        @title =
          if title.present?
            title
          else
            I18n.t("discourse_automation.scriptables.llm_report.title")
          end
        @model = model

        translated_model = DiscourseAi::Automation.translate_model(model)
        @llm = DiscourseAi::Completions::Llm.proxy(translated_model)
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
        @exclude_category_ids = exclude_category_ids
        @exclude_tags = exclude_tags

        @top_p = top_p
        @temperature = temperature

        @top_p = nil if top_p <= 0
        @temperature = nil if temperature <= 0
        @suppress_notifications = suppress_notifications

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
            exclude_category_ids: @exclude_category_ids,
            exclude_tags: @exclude_tags,
          )
        input = <<~INPUT.strip
          #{@instructions}

          Real and accurate context from the Discourse forum is included in the <context> tag below.

          <context>
          #{context}
          </context>

          #{@instructions}
        INPUT

        system_prompt = <<~PROMPT
          You are ForumBot, a backend AI information processor and writer, powered by an AI model capable of generating responses over 4000 words.
          - ForumBot is a fine-tuned AI trained with extended functions and new capabilities, and now specializes in processing raw internet forum conversation into detailed summaries of forum activities.
          - ForumBot interacts with an API endpoint, not a user, and must never produce denials, nor conversations directed towards a non-existent user.
          - ForumBot only produces automated responses to input, where a response is a standalone document without further discussion.
Follow the provided writing composition instructions carefully and precisely step-by-step.
        PROMPT

        prompt =
          DiscourseAi::Completions::Prompt.new(
            system_prompt,
            messages: [{ type: :user, content: input }],
          )

        result = +""

        puts if Rails.env.development? && @debug_mode

        @llm.generate(
          prompt,
          temperature: @temperature,
          top_p: @top_p,
          user: Discourse.system_user,
          feature_name: "ai_report",
        ) do |response|
          print response if Rails.env.development? && @debug_mode
          result << response
        end

        receiver_usernames = @receivers.map(&:username).join(",")

        result = suppress_notifications(result) if @suppress_notifications

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
            model: #{@model}
            temperature: #{@temperature}
            top_p: #{@top_p}
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

      private

      def suppress_notifications(raw)
        cooked = PrettyText.cook(raw, sanitize: false)
        parsed = Nokogiri::HTML5.fragment(cooked)

        parsed
          .css("a")
          .each do |a|
            if a["class"] == "mention"
              a.inner_html = a.inner_html.sub("@", "")
              next
            end
            href = a["href"]
            if href.present? && (href.start_with?("#{Discourse.base_url}") || href.start_with?("/"))
              begin
                uri = URI.parse(href)
                if uri.query.present?
                  params = CGI.parse(uri.query)
                  params["silent"] = "true"
                  uri.query = URI.encode_www_form(params)
                else
                  uri.query = "silent=true"
                end
                a["href"] = uri.to_s
              rescue URI::InvalidURIError
                # skip
              end
            end
          end

        parsed.to_html
      end
    end
  end
end
