# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class Playground
      # An abstraction to manage the bot and topic interactions.
      # The bot will take care of completions while this class updates the topic title
      # and stream replies.

      REQUIRE_TITLE_UPDATE = "discourse-ai-title-update"

      def initialize(bot)
        @bot = bot
      end

      def update_playground_with(post)
        if can_attach?(post) && bot.bot_user
          schedule_playground_titling(post, bot.bot_user)
          schedule_bot_reply(post, bot.bot_user)
        end
      end

      def conversation_context(post)
        # Pay attention to the `post_number <= ?` here.
        # We want to inject the last post as context because they are translated differently.
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
          custom_prompt_translation =
            Proc.new do |message|
              # We can't keep backwards-compatibility for stored functions.
              # Tool syntax requires a tool_call_id which we don't have.
              if message[2] != "function"
                custom_context = {
                  content: message[0],
                  type: message[2].present? ? message[2] : "assistant",
                }

                custom_context[:name] = message[1] if custom_context[:type] != "assistant"

                custom_context
              end
            end

          if custom_prompt.present?
            result << {
              type: "multi_turn",
              content: custom_prompt.reverse_each.map(&custom_prompt_translation).compact,
            }
          else
            context = {
              content: raw,
              type: (available_bot_usernames.include?(username) ? "assistant" : "user"),
            }

            context[:name] = clean_username(username) if context[:type] == "user"

            result << context
          end
        end

        result
      end

      def title_playground(post)
        context = conversation_context(post)

        bot
          .get_updated_title(context, post.user)
          .tap do |new_title|
            PostRevisor.new(post.topic.first_post, post.topic).revise!(
              bot.bot_user,
              title: new_title.sub(/\A"/, "").sub(/"\Z/, ""),
            )
            post.topic.custom_fields.delete(DiscourseAi::AiBot::EntryPoint::REQUIRE_TITLE_UPDATE)
            post.topic.save_custom_fields
          end
      end

      def reply_to(post)
        reply = +""
        start = Time.now

        context = {
          site_url: Discourse.base_url,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          time: Time.zone.now,
          participants: post.topic.allowed_users.map(&:username).join(", "),
          conversation_context: conversation_context(post),
          user: post.user,
        }

        reply_post =
          PostCreator.create!(
            bot.bot_user,
            topic_id: post.topic_id,
            raw: I18n.t("discourse_ai.ai_bot.placeholder_reply"),
            skip_validations: true,
          )

        redis_stream_key = "gpt_cancel:#{reply_post.id}"
        Discourse.redis.setex(redis_stream_key, 60, 1)

        new_custom_prompts =
          bot.reply(context) do |partial, cancel, placeholder|
            reply << partial
            raw = reply.dup
            raw << "\n\n" << placeholder if placeholder.present?

            if !Discourse.redis.get(redis_stream_key)
              cancel&.call

              reply_post.update!(raw: reply, cooked: PrettyText.cook(reply))
            end

            # Minor hack to skip the delay during tests.
            if placeholder.blank?
              next if (Time.now - start < 0.5) && !Rails.env.test?
              start = Time.now
            end

            Discourse.redis.expire(redis_stream_key, 60)

            publish_update(reply_post, raw: raw)
          end

        return if reply.blank?

        reply_post.tap do |bot_reply|
          publish_update(bot_reply, done: true)

          bot_reply.revise(
            bot.bot_user,
            { raw: reply },
            skip_validations: true,
            skip_revision: true,
          )

          bot_reply.post_custom_prompt ||= bot_reply.build_post_custom_prompt(custom_prompt: [])
          prompt = bot_reply.post_custom_prompt.custom_prompt || []
          prompt.concat(new_custom_prompts)
          prompt << [reply, bot.bot_user.username]
          bot_reply.post_custom_prompt.update!(custom_prompt: prompt)
        end
      end

      private

      attr_reader :bot

      def can_attach?(post)
        return false if bot.bot_user.nil?
        return false if post.post_type != Post.types[:regular]
        return false unless post.topic.private_message?
        return false if (SiteSetting.ai_bot_allowed_groups_map & post.user.group_ids).blank?

        true
      end

      def schedule_playground_titling(post, bot_user)
        if post.post_number == 1
          post.topic.custom_fields[REQUIRE_TITLE_UPDATE] = true
          post.topic.save_custom_fields
        end

        ::Jobs.enqueue_in(
          5.minutes,
          :update_ai_bot_pm_title,
          post_id: post.id,
          bot_user_id: bot_user.id,
        )
      end

      def schedule_bot_reply(post, bot_user)
        ::Jobs.enqueue(:create_ai_reply, post_id: post.id, bot_user_id: bot_user.id)
      end

      def context(topic)
        {
          site_url: Discourse.base_url,
          site_title: SiteSetting.title,
          site_description: SiteSetting.site_description,
          time: Time.zone.now,
          participants: topic.allowed_users.map(&:username).join(", "),
        }
      end

      def publish_update(bot_reply_post, payload)
        MessageBus.publish(
          "discourse-ai/ai-bot/topic/#{bot_reply_post.topic_id}",
          payload.merge(post_id: bot_reply_post.id, post_number: bot_reply_post.post_number),
          user_ids: bot_reply_post.topic.allowed_user_ids,
        )
      end

      def available_bot_usernames
        @bot_usernames ||= DiscourseAi::AiBot::EntryPoint::BOTS.map(&:second)
      end

      def clean_username(username)
        if username.match?(/\0[a-zA-Z0-9_-]{1,64}\z/)
          username
        else
          # not the best in the world, but this is what we have to work with
          # if sites enable unicode usernames this can get messy
          username.gsub(/[^a-zA-Z0-9_-]/, "_")[0..63]
        end
      end
    end
  end
end
