# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationsController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login

      def index
        # Step 1: Retrieve all AI bot user IDs
        bot_user_ids = EntryPoint.all_bot_ids

        # Step 2: Query for PM topics including current_user and any bot ID
        pms =
          Topic
            .private_messages_for_user(current_user)
            .joins(:topic_users)
            .where(topic_users: { user_id: bot_user_ids })
            .distinct

        # Step 3: Serialize (empty array if no results)
        serialized_pms = serialize_data(pms, BasicTopicSerializer)

        render json: serialized_pms, status: 200
      end
    end
  end
end
