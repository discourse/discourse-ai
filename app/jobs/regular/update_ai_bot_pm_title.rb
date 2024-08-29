# frozen_string_literal: true

module ::Jobs
  class UpdateAiBotPmTitle < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless bot = DiscourseAi::AiBot::Bot.as(bot_user, model: args[:model])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])

      return unless post.topic.custom_fields[DiscourseAi::AiBot::EntryPoint::REQUIRE_TITLE_UPDATE]

      DiscourseAi::AiBot::Playground.new(bot).title_playground(post)

      publish_update(post.topic, { title: post.topic.title })
    end

    def publish_update(topic, payload)
      allowed_users = topic.topic_allowed_users.pluck(:user_id)
      MessageBus.publish("/discourse-ai/ai-bot/topic/#{topic.id}", payload, user_ids: allowed_users)
    end
  end
end
