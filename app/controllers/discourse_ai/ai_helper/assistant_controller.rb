# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions

      def prompts
        render json:
                 ActiveModel::ArraySerializer.new(
                   DiscourseAi::AiHelper::LlmPrompt.new.available_prompts,
                   root: false,
                 ),
               status: 200
      end

      def suggest
        raise Discourse::InvalidParameters.new(:text) if params[:text].blank?

        prompt = CompletionPrompt.find_by(id: params[:mode])
        raise Discourse::InvalidParameters.new(:mode) if !prompt || !prompt.enabled?

        RateLimiter.new(current_user, "ai_assistant", 6, 3.minutes).performed!

        hijack do
          render json:
                   DiscourseAi::AiHelper::LlmPrompt.new.generate_and_send_prompt(
                     prompt,
                     params[:text],
                   ),
                 status: 200
        end
      rescue ::DiscourseAi::Inference::OpenAiCompletions::CompletionFailed,
             ::DiscourseAi::Inference::AnthropicCompletions::CompletionFailed => e
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
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
