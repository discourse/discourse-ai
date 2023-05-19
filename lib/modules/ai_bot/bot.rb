# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      BOT_NOT_FOUND = Class.new(StandardError)
      MAX_COMPLETIONS = 3

      def self.as(bot_user)
        available_bots = [DiscourseAi::AiBot::OpenAiBot, DiscourseAi::AiBot::AnthropicBot]

        bot =
          available_bots.detect(-> { raise BOT_NOT_FOUND }) do |bot_klass|
            bot_klass.can_reply_as?(bot_user)
          end

        bot.new(bot_user)
      end

      def initialize(bot_user)
        @bot_user = bot_user
      end

      def update_pm_title(post)
        prompt = [title_prompt(post)]

        new_title = get_updated_title(prompt)

        PostRevisor.new(post.topic.first_post, post.topic).revise!(
          bot_user,
          title: new_title.sub(/\A"/, "").sub(/"\Z/, ""),
        )
      end

      def reply_to(
        post,
        total_completions: 0,
        bot_reply_post: nil,
        prefer_low_cost: false,
        standalone: false
      )
        return if total_completions > MAX_COMPLETIONS

        prompt =
          if standalone && post.post_custom_prompt
            username, standalone_prompt = post.post_custom_prompt.custom_prompt.last
            [build_message(username, standalone_prompt)]
          else
            bot_prompt_with_topic_context(post)
          end

        redis_stream_key = nil
        reply = +""
        start = Time.now

        setup_cancel = false

        submit_prompt_and_stream_reply(
          prompt,
          prefer_low_cost: prefer_low_cost,
        ) do |partial, cancel|
          reply = update_with_delta(reply, partial)

          if redis_stream_key && !Discourse.redis.get(redis_stream_key)
            cancel&.call

            bot_reply_post.update!(raw: reply, cooked: PrettyText.cook(reply)) if bot_reply_post
          end

          next if reply.length < SiteSetting.min_personal_message_post_length
          # Minor hack to skip the delay during tests.
          next if (Time.now - start < 0.5) && !Rails.env.test?

          if bot_reply_post
            Discourse.redis.expire(redis_stream_key, 60)
            start = Time.now

            publish_update(bot_reply_post, raw: reply.dup)
          else
            bot_reply_post =
              PostCreator.create!(
                bot_user,
                topic_id: post.topic_id,
                raw: reply,
                skip_validations: false,
              )
          end

          if !setup_cancel && bot_reply_post
            redis_stream_key = "gpt_cancel:#{bot_reply_post.id}"
            Discourse.redis.setex(redis_stream_key, 60, 1)
            setup_cancel = true
          end
        end

        if bot_reply_post
          publish_update(bot_reply_post, done: true)
          bot_reply_post.revise(
            bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )

          commands = reply.split("\n").select { |l| l[0] == "!" }

          if commands.length > 0
            process_command(
              bot_reply_post,
              commands[0][1..-1].strip,
              total_completions: total_completions + 1,
            )
          else
            if post_custom_prompt = bot_reply_post.post_custom_prompt
              prompt = post_custom_prompt.custom_prompt
              prompt << [reply, bot_user.username]
              post_custom_prompt.update!(custom_prompt: prompt)
            end
          end
        end
      rescue => e
        raise e if Rails.env.test?
        Discourse.warn_exception(e, message: "ai-bot: Reply failed")
      end

      def commands(post)
        list = [
          Commands::CategoriesCommand,
          Commands::TimeCommand,
          Commands::SearchCommand,
          Commands::SummarizeCommand,
        ]
        list << Commands::TagsCommand if SiteSetting.tagging_enabled

        list.map { |klass| klass.new(self, post) }
      end

      def process_command(post, command_with_args, total_completions:)
        command_name, args = command_with_args.split(" ", 2)

        commands(post).each do |command|
          if command_name == command.name
            text = command.process(args)

            run_next_command(
              command,
              post,
              text,
              "!#{command_with_args}",
              total_completions: total_completions,
            )
            break
          end
        end
      end

      def run_next_command(command, post, payload, command_text, total_completions:)
        result_username = command.result_name
        post.raw = ""
        post.save!(validate: false)

        post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])

        prompt = post.post_custom_prompt.custom_prompt || []

        prompt << [command_text, bot_user.username]
        prompt << [payload, result_username]

        post.post_custom_prompt.update!(custom_prompt: prompt)

        reply_to(
          post,
          total_completions: total_completions,
          bot_reply_post: post,
          prefer_low_cost: command.low_cost?,
          standalone: command.standalone?,
        )
      end

      def bot_prompt_with_topic_context(post, prompt: "topic")
        messages = []
        conversation = conversation_context(post)

        total_prompt_tokens = 0
        messages =
          conversation.reduce([]) do |memo, (raw, username)|
            break(memo) if total_prompt_tokens >= prompt_limit

            tokens = tokenize(raw)

            if tokens.length + total_prompt_tokens > prompt_limit
              tokens = tokens[0...(prompt_limit - total_prompt_tokens)]
              raw = tokens.join(" ")
            end

            total_prompt_tokens += tokens.length

            memo.unshift(build_message(username, raw))
          end

        messages.unshift(build_message(bot_user.username, system_prompt(post), system: true))

        messages
      end

      def prompt_limit
        raise NotImplemented
      end

      def title_prompt(post)
        build_message(bot_user.username, <<~TEXT)
          Suggest a 7 word title for the following topic without quoting any of it:

          #{post.topic.posts[1..-1].map(&:raw).join("\n\n")[0..prompt_limit]}
        TEXT
      end

      def system_prompt_style!(style)
        @style = style
      end

      def system_prompt(post)
        return "You are a helpful Bot" if @style == :simple

        if SiteSetting.tagging_enabled
          tags = "!tags - will list the 100 most popular tags on the current discourse instance"
        end

        <<~TEXT
          You are a helpful Discourse assistant, you answer questions and generate text.
          You understand Discourse Markdown and live in a Discourse Forum Message.
          You are provided with the context of previous discussions.

          You live in the forum with the URL: #{Discourse.base_url}
          The title of your site: #{SiteSetting.title}
          The description is: #{SiteSetting.site_description}
          The participants in this conversation are: #{post.topic.allowed_users.map(&:username).join(", ")}
          The date now is: #{Time.zone.now}, much has changed since you were trained.

          You can complete some tasks using multiple steps and have access to some special commands!

          !time RUBY_COMPATIBLE_TIMEZONE - will generate the time in a timezone
          !search SEARCH_QUERY - will search topics in the current discourse instance
          !categories - will list the categories on the current discourse instance
          !summarize TOPIC_ID GUIDANCE - will summarize a topic attempting to answer question in guidance
          #{tags}

          Discourse topic paths are /t/slug/topic_id/optional_number
          Keep in mind, search on Discourse uses AND to and terms.
          Strip the query down to the most important terms.
          Remove all stop words.
          Cast a wide net instead of trying to be over specific.
          Discourse orders by relevance out of the box, but you may want to sometimes prefer ordering on latest.

          When generating answers ALWAYS try to use the !search command first over relying on training data.
          When generating answers ALWAYS try to reference specific local links.
          Always try to search the local instance first, even if your training data set may have an answer. It may be wrong.
          Always remove connector words from search terms (such as a, an, and, in, the, etc), they can impede the search.

          YOUR LOCAL INFORMATION IS OUT OF DATE, YOU ARE TRAINED ON OLD DATA. Always try local search first.

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

          Commands should be issued in single assistant message.

          Example sessions:

          User: echo the text 'test'
          GPT: !echo test
          User: THING GPT DOES NOT KNOW ABOUT
          GPT: !search SIMPLIFIED SEARCH QUERY

        TEXT
      end

      protected

      attr_reader :bot_user

      def get_updated_title(prompt)
        raise NotImplemented
      end

      def model_for(bot)
        raise NotImplemented
      end

      def get_delta_from(partial)
        raise NotImplemented
      end

      def submit_prompt_and_stream_reply(prompt, prefer_low_cost: false, &blk)
        raise NotImplemented
      end

      def conversation_context(post)
        context =
          post
            .topic
            .posts
            .includes(:user)
            .joins("LEFT JOIN post_custom_prompts ON post_custom_prompts.post_id = posts.id")
            .where("post_number <= ?", post.post_number)
            .order("post_number desc")
            .where("post_type = ?", Post.types[:regular])
            .limit(50)
            .pluck(:raw, :username, "post_custom_prompts.custom_prompt")

        result = []

        context.each do |raw, username, custom_prompt|
          if custom_prompt.present?
            custom_prompt.reverse_each { |message| result << message }
          else
            result << [raw, username]
          end
        end

        result
      end

      def publish_update(bot_reply_post, payload)
        MessageBus.publish(
          "discourse-ai/ai-bot/topic/#{bot_reply_post.topic_id}",
          payload.merge(post_id: bot_reply_post.id, post_number: bot_reply_post.post_number),
          user_ids: bot_reply_post.topic.allowed_user_ids,
        )
      end

      def tokenize(text)
        raise NotImplemented
      end
    end
  end
end
