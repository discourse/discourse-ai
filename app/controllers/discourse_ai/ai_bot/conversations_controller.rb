# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      def index
        page = params[:page]&.to_i || 0
        per_page = params[:per_page]&.to_i || 40

        # Step 1: Retrieve all AI bot user IDs
        bot_user_ids = EntryPoint.all_bot_ids

        # Step 2: Query for PM topics including current_user and any bot ID
        #pms =
        #Topic
        #.private_messages_for_user(current_user)
        #.joins(:topic_users)
        #.where(topic_users: { user_id: bot_user_ids })
        #.distinct
        #.order(last_posted_at: :desc)
        #.offset(page * per_page)
        #.limit(per_page)

        #total = Topic
        #.private_messages_for_user(current_user)
        #.joins(:topic_users)
        #.where(topic_users: { user_id: bot_user_ids })
        #.distinct
        #.count

        pms =
          Topic
            .private_messages_for_user(current_user)
            .order(last_posted_at: :desc)
            .offset(page * per_page)
            .limit(per_page)
        total = Topic.private_messages_for_user(current_user).count

        render json: {
                 conversations: serialize_data(pms, BasicTopicSerializer),
                 meta: {
                   total: total,
                   page: page,
                   per_page: per_page,
                   more: total > (page + 1) * per_page,
                 },
               }
      end
    end
  end
end
