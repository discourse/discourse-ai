# frozen_string_literal: true

module DiscourseAi
  module GuardianExtensions
    def can_share_ai_bot_conversation?(target)
      return false if anonymous?

      if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_enabled ||
           !SiteSetting.ai_bot_public_sharing_allowed_groups_map.any?
        return false
      end

      return false if !user.in_any_groups?(SiteSetting.ai_bot_public_sharing_allowed_groups_map)

      # In future we may add other valid targets for AI conversation sharing,
      # for now we only support topics.
      if target.is_a?(Topic)
        return false if !target.private_message?
        return false if target.topic_allowed_groups.exists?
        return false if !target.topic_allowed_users.exists?(user_id: user.id)

        # other people in PM
        if target.topic_allowed_users.where("user_id > 0 and user_id <> ?", user.id).exists?
          return false
        end

        # other content in PM
        return false if target.posts.where("user_id > 0 and user_id <> ?", user.id).exists?
      end

      true
    end

    def can_destroy_shared_ai_bot_conversation?(conversation)
      return false if anonymous?

      conversation.user_id == user.id || is_admin?
    end
  end
end
