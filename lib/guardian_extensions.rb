# frozen_string_literal: true

module DiscourseAi
  module GuardianExtensions
    def can_see_summary?(target)
      return false if !SiteSetting.ai_summarization_enabled

      # TODO we want a switch to allow summaries for all topics
      return false if target.class == Topic && target.private_message?

      has_cached_summary = AiSummary.exists?(target: target)
      return has_cached_summary if user.nil?

      has_cached_summary || can_request_summary?
    end

    def can_request_summary?
      return false if anonymous?

      user_group_ids = user.group_ids
      SiteSetting.ai_custom_summarization_allowed_groups_map.any? do |group_id|
        user_group_ids.include?(group_id)
      end
    end

    def can_debug_ai_bot_conversation?(target)
      return false if anonymous?

      return false if !can_see?(target)

      if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_enabled ||
           !SiteSetting.ai_bot_debugging_allowed_groups_map.any?
        return false
      end

      user.in_any_groups?(SiteSetting.ai_bot_debugging_allowed_groups_map)
    end

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
        allowed_user_ids = target.topic_allowed_users.pluck(:user_id)

        # not in PM
        return false if !allowed_user_ids.include?(user.id)

        # other people in PM
        return false if allowed_user_ids.any? { |id| id > 0 && id != user.id }

        # no bot in the PM
        bot_ids = DiscourseAi::AiBot::EntryPoint.all_bot_ids
        return false if allowed_user_ids.none? { |id| bot_ids.include?(id) }

        # other content in PM
        return false if target.posts.where("user_id > 0 and user_id <> ?", user.id).exists?
      else
        return false
      end

      true
    end

    def can_destroy_shared_ai_bot_conversation?(conversation)
      return false if anonymous?

      conversation.user_id == user.id || is_admin?
    end
  end
end
