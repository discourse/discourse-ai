# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions
      before_action :rate_limiter_performed!, except: %i[prompts]

      def prompts
        render json:
                 ActiveModel::ArraySerializer.new(
                   DiscourseAi::AiHelper::Assistant.new.available_prompts,
                   root: false,
                 ),
               status: 200
      end

      def suggest
        input = get_text_param!

        prompt = CompletionPrompt.find_by(id: params[:mode])

        raise Discourse::InvalidParameters.new(:mode) if !prompt || !prompt.enabled?

        if prompt.id == CompletionPrompt::CUSTOM_PROMPT
          raise Discourse::InvalidParameters.new(:custom_prompt) if params[:custom_prompt].blank?

          prompt.custom_instruction = params[:custom_prompt]
        end

        hijack do
          render json:
                   DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
                     prompt,
                     input,
                     current_user,
                   ),
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => e
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def suggest_title
        input = get_text_param!

        prompt = CompletionPrompt.enabled_by_name("generate_titles")
        raise Discourse::InvalidParameters.new(:mode) if !prompt

        hijack do
          render json:
                   DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
                     prompt,
                     input,
                     current_user,
                   ),
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => e
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def suggest_category
        input = get_text_param!
        input_hash = { text: input }

        render json:
                 DiscourseAi::AiHelper::SemanticCategorizer.new(
                   input_hash,
                   current_user,
                 ).categories,
               status: 200
      end

      def suggest_tags
        input = get_text_param!
        input_hash = { text: input }

        render json: DiscourseAi::AiHelper::SemanticCategorizer.new(input_hash, current_user).tags,
               status: 200
      end

      def suggest_thumbnails
        input = get_text_param!

        hijack do
          thumbnails = DiscourseAi::AiHelper::Painter.new.commission_thumbnails(input, current_user)

          render json: { thumbnails: thumbnails }, status: 200
        end
      end

      def explain
        post_id = get_post_param!
        term_to_explain = get_text_param!
        post = Post.includes(:topic).find_by(id: post_id)

        raise Discourse::InvalidParameters.new(:post_id) unless post

        render json:
                 DiscourseAi::AiHelper::TopicHelper.new(current_user).explain(
                   term_to_explain,
                   post,
                 ),
               status: 200
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => e
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      private

      def get_text_param!
        params[:text].tap { |t| raise Discourse::InvalidParameters.new(:text) if t.blank? }
      end

      def get_post_param!
        params[:post_id].tap { |t| raise Discourse::InvalidParameters.new(:post_id) if t.blank? }
      end

      def rate_limiter_performed!
        RateLimiter.new(current_user, "ai_assistant", 6, 3.minutes).performed!
      end

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
