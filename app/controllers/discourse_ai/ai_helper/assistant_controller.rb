# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions
      before_action :rate_limiter_performed!

      include SecureUploadEndpointHelpers

      def suggest
        input = get_text_param!
        force_default_locale = params[:force_default_locale] || false

        prompt = CompletionPrompt.find_by(id: params[:mode])

        raise Discourse::InvalidParameters.new(:mode) if !prompt || !prompt.enabled?

        if prompt.id == CompletionPrompt::CUSTOM_PROMPT
          raise Discourse::InvalidParameters.new(:custom_prompt) if params[:custom_prompt].blank?

          prompt.custom_instruction = params[:custom_prompt]
        end

        suggest_thumbnails(input) if prompt.id == CompletionPrompt::ILLUSTRATE_POST

        hijack do
          render json:
                   DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
                     prompt,
                     input,
                     current_user,
                     force_default_locale,
                   ),
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
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
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
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

      def suggest_thumbnails(input)
        hijack do
          thumbnails = DiscourseAi::AiHelper::Painter.new.commission_thumbnails(input, current_user)

          render json: { thumbnails: thumbnails }, status: 200
        end
      end

      def stream_suggestion
        post_id = get_post_param!
        text = get_text_param!
        post = Post.includes(:topic).find_by(id: post_id)
        prompt = CompletionPrompt.find_by(id: params[:mode])

        raise Discourse::InvalidParameters.new(:mode) if !prompt || !prompt.enabled?
        raise Discourse::InvalidParameters.new(:post_id) unless post

        if prompt.id == CompletionPrompt::CUSTOM_PROMPT
          raise Discourse::InvalidParameters.new(:custom_prompt) if params[:custom_prompt].blank?
        end

        Jobs.enqueue(
          :stream_post_helper,
          post_id: post.id,
          user_id: current_user.id,
          text: text,
          prompt: prompt.name,
          custom_prompt: params[:custom_prompt],
        )

        render json: { success: true }, status: 200
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def caption_image
        image_url = params[:image_url]
        image_url_type = params[:image_url_type]

        raise Discourse::InvalidParameters.new(:image_url) if !image_url
        raise Discourse::InvalidParameters.new(:image_url) if !image_url_type

        if image_url_type == "short_path"
          image = Upload.find_by(sha1: Upload.sha1_from_short_path(image_url))
        elsif image_url_type == "short_url"
          image = Upload.find_by(sha1: Upload.sha1_from_short_url(image_url))
        else
          image = upload_from_full_url(image_url)
        end

        raise Discourse::NotFound if image.blank?

        check_secure_upload_permission(image) if image.secure?
        user = current_user

        hijack do
          caption = DiscourseAi::AiHelper::Assistant.new.generate_image_caption(image, user)
          render json: {
                   caption:
                     "#{caption} (#{I18n.t("discourse_ai.ai_helper.image_caption.attribution")})",
                 },
                 status: 200
        end
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed, Net::HTTPBadResponse
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
        if action_name == "caption_image"
          RateLimiter.new(current_user, "ai_assistant_caption_image", 20, 1.minute).performed!
        else
          RateLimiter.new(current_user, "ai_assistant", 6, 3.minutes).performed!
        end
      end

      def ensure_can_request_suggestions
        allowed_groups =
          (
            SiteSetting.composer_ai_helper_allowed_groups_map |
              SiteSetting.post_ai_helper_allowed_groups_map
          )

        raise Discourse::InvalidAccess if !current_user.in_any_groups?(allowed_groups)
      end
    end
  end
end
