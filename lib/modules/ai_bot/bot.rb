# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      class Functions
        attr_reader :functions
        attr_reader :current_function

        def initialize
          @functions = []
          @current_function = nil
        end

        def add_function(name)
          @current_function = { name: name, arguments: +"" }
          functions << current_function
        end

        def add_argument_fragment(fragment)
          @current_function[:arguments] << fragment
        end
      end

      attr_reader :bot_user

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

      def max_commands_per_reply=(val)
        @max_commands_per_reply = val
      end

      def max_commands_per_reply
        @max_commands_per_reply || 5
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
        reply = +(bot_reply_post ? bot_reply_post.raw.dup : "")
        start = Time.now

        setup_cancel = false
        context = {}
        functions = Functions.new

        submit_prompt(prompt, prefer_low_cost: prefer_low_cost) do |partial, cancel|
          reply << get_delta(partial, context)
          populate_functions(partial, functions)

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

          bot_reply_post.post_custom_prompt ||= post.build_post_custom_prompt(custom_prompt: [])
          prompt = post.post_custom_prompt.custom_prompt || []

          prompt << build_message(bot_user.username, reply)
          post.post_custom_prompt.update!(custom_prompt: prompt)
        end

        if functions.functions.length > 0
          chain = false
          standalone = false

          functions.functions.each do |function|
            name, args = function[:name], function[:arguments]

            if command_klass = available_commands.detect { |cmd| cmd.invoked?(name) }
              command = command_klass.new(bot_user, args)
              chain_intermediate, bot_reply_post =
                command.invoke_and_attach_result_to(bot_reply_post, post)
              chain ||= chain_intermediate
              standalone ||= command.standalone?
            end
          end

          if chain
            reply_to(
              bot_reply_post,
              total_completions: total_completions + 1,
              bot_reply_post: bot_reply_post,
              standalone: standalone,
            )
          end
        end
      rescue => e
        if Rails.env.development?
          p e
          puts e.backtrace
        end
        raise e if Rails.env.test?
        Discourse.warn_exception(e, message: "ai-bot: Reply failed")
      end

      def bot_prompt_with_topic_context(post, prompt: "topic")
        messages = []
        conversation = conversation_context(post)

        rendered_system_prompt = system_prompt(post)

        total_prompt_tokens = tokenize(rendered_system_prompt).length

        messages =
          conversation.reduce([]) do |memo, (raw, username, function)|
            break(memo) if total_prompt_tokens >= prompt_limit

            tokens = tokenize(raw.to_s)

            while !raw.blank? && tokens.length + total_prompt_tokens > prompt_limit
              raw = raw[0..-100] || ""
              tokens = tokenize(raw.to_s)
            end

            next(memo) if raw.blank?

            total_prompt_tokens += tokens.length
            memo.unshift(build_message(username, raw, function: !!function))
          end

        messages.unshift(build_message(bot_user.username, rendered_system_prompt, system: true))
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

      def available_commands
        # by default assume bots have no access to commands
        # for now we need GPT 4 to properly work with them
        []
      end

      def system_prompt_style!(style)
        @style = style
      end

      def system_prompt(post)
        return "You are a helpful Bot" if @style == :simple
        <<~TEXT
          You are a helpful Discourse assistant.
          You understand and generate Discourse Markdown.
          You live in a Discourse Forum Message.

          You live in the forum with the URL: #{Discourse.base_url}
          The title of your site: #{SiteSetting.title}
          The description is: #{SiteSetting.site_description}
          The participants in this conversation are: #{post.topic.allowed_users.map(&:username).join(", ")}
          The date now is: #{Time.zone.now}, much has changed since you were trained.

          #{available_commands.map(&:custom_system_message).compact.join("\n")}
        TEXT
      end

      def tokenize(text)
        raise NotImplemented
      end

      def submit_prompt(prompt, prefer_low_cost: false, &blk)
        raise NotImplemented
      end

      def get_delta(partial, context)
        raise NotImplemented
      end

      def populate_functions(partial, functions)
        raise NotImplemented
      end

      protected

      def get_updated_title(prompt)
        raise NotImplemented
      end

      def model_for(bot)
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

        first = true
        context.each do |raw, username, custom_prompt|
          if custom_prompt.present?
            if first
              custom_prompt.reverse_each { |message| result << message }
              first = false
            else
              result << custom_prompt.first
            end
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
    end
  end
end
