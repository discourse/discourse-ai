# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])

      prompt = CompletionPrompt.bot_prompt_with_topic_context(post)

      redis_stream_key = nil
      reply = +""
      bot_reply_post = nil
      start = Time.now

      DiscourseAi::Inference::OpenAiCompletions.perform!(
        prompt,
        temperature: 0.4,
        top_p: 0.9,
        max_tokens: 3000,
      ) do |partial, cancel|
        content_delta = partial.dig(:choices, 0, :delta, :content)
        reply << content_delta if content_delta

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

          MessageBus.publish(
            "discourse-ai/ai-bot/topic/#{post.topic_id}",
            { raw: reply.dup, post_id: bot_reply_post.id, post_number: bot_reply_post.post_number },
            user_ids: post.topic.allowed_user_ids,
          )
        else
          bot_reply_post =
            PostCreator.create!(
              Discourse.gpt_bot,
              topic_id: post.topic_id,
              raw: reply,
              skip_validations: false,
            )
          redis_stream_key = "gpt_cancel:#{bot_reply_post.id}"
          Discourse.redis.setex(redis_stream_key, 60, 1)
        end
      end

      MessageBus.publish(
        "discourse-ai/ai-bot/topic/#{post.topic_id}",
        { done: true, post_id: bot_reply_post.id, post_number: bot_reply_post.post_number },
        user_ids: post.topic.allowed_user_ids,
      )

      if bot_reply_post
        bot_reply_post.revise(
          Discourse.gpt_bot,
          { raw: reply },
          skip_validations: true,
          skip_revision: true,
        )
      end
    rescue => e
      Discourse.warn_exception(e, message: "ai-bot: Reply failed")
    end
  end
end
