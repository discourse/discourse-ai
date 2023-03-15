# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions

      def suggest
        raise Discourse::InvalidParameters.new(:text) if params[:text].blank?

        if !DiscourseAi::AiHelper::OpenAiPrompt::VALID_TYPES.include?(params[:mode])
          raise Discourse::InvalidParameters.new(:mode)
        end

        RateLimiter.new(current_user, "ai_assistant", 6, 3.minutes).performed!

        hijack do
          render json:
                   DiscourseAi::AiHelper::OpenAiPrompt.new.generate_and_send_prompt(
                     params[:mode],
                     params[:text],
                   ),
                 status: 200
        end
      end

      private

      def ensure_can_request_suggestions
        user_group_ids = current_user.group_ids

        allowed =
          SiteSetting.ai_helper_allowed_groups_map.any? do |group_id|
            user_group_ids.include?(group_id)
          end

        raise Discourse::InvalidAccess if !allowed
      end
    end
  end
end
