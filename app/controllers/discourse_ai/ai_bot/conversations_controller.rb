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
            .joins(:topic_users)
            .private_messages
            .where("topic_users.user_id IN (?)", bot_user_ids + [current_user.id])
            .group("topics.id") # Group by topic to ensure distinct results
            .having("COUNT(topic_users.user_id) > 1") # Ensure multiple participants in the PM

        # Step 3: Serialize (empty array if no results)
        serialized_pms = serialize_data(pms, BasicTopicSerializer)

        render json: serialized_pms, status: 200
      end
    end
  end
end
