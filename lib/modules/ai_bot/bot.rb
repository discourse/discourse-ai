# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Bot
      BOT_NOT_FOUND = Class.new(StandardError)

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

      def reply_to(post)
        prompt = bot_prompt_with_topic_context(post)

        redis_stream_key = nil
        reply = +""
        bot_reply_post = nil
        start = Time.now

        submit_prompt_and_stream_reply(prompt) do |partial, cancel|
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
            redis_stream_key = "gpt_cancel:#{bot_reply_post.id}"
            Discourse.redis.setex(redis_stream_key, 60, 1)
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
        end
      rescue => e
        Discourse.warn_exception(e, message: "ai-bot: Reply failed")
      end

      def bot_prompt_with_topic_context(post)
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

        messages.unshift(build_message(bot_user.username, <<~TEXT))
          You are gpt-bot. You answer questions and generate text.
          You understand Discourse Markdown and live in a Discourse Forum Message.
          You are provided you with context of previous discussions.
        TEXT

        messages
      end

      def prompt_limit
        raise NotImplemented
      end

      protected

      attr_reader :bot_user

      def model_for(bot)
        raise NotImplemented
      end

      def get_delta_from(partial)
        raise NotImplemented
      end

      def submit_prompt_and_stream_reply(prompt, &blk)
        raise NotImplemented
      end

      def conversation_context(post)
        post
          .topic
          .posts
          .includes(:user)
          .where("post_number <= ?", post.post_number)
          .order("post_number desc")
          .pluck(:raw, :username)
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
