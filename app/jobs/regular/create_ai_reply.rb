# frozen_string_literal: true

module ::Jobs
  class CreateAiReply < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless bot_user = User.find_by(id: args[:bot_user_id])
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      agent_id = args[:agent_id]

      begin
        agent = DiscourseAi::Agents::Agent.find_by(user: post.user, id: agent_id)
        raise DiscourseAi::Agents::Bot::BOT_NOT_FOUND if agent.nil?

        bot = DiscourseAi::Agents::Bot.as(bot_user, agent: agent.new)

        DiscourseAi::AiBot::Playground.new(bot).reply_to(post)
      rescue DiscourseAi::Agents::Bot::BOT_NOT_FOUND
        Rails.logger.warn(
          "Bot not found for post #{post.id} - perhaps agent was deleted or bot was disabled",
        )
      end
    end
  end
end
