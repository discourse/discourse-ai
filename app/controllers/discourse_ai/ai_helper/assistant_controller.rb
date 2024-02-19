# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class AssistantController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME
      requires_login
      before_action :ensure_can_request_suggestions
      before_action :rate_limiter_performed!, except: %i[prompts]

      def suggest
        input = get_text_param!

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

      def explain
        post_id = get_post_param!
        term_to_explain = get_text_param!
        post = Post.includes(:topic).find_by(id: post_id)

        raise Discourse::InvalidParameters.new(:post_id) unless post

        Jobs.enqueue(
          :stream_post_helper,
          post_id: post.id,
          user_id: current_user.id,
          term_to_explain: term_to_explain,
        )

        render json: { success: true }, status: 200
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed
        render_json_error I18n.t("discourse_ai.ai_helper.errors.completion_request_failed"),
                          status: 502
      end

      def caption_image
        image_url = params[:image_url]
        raise Discourse::InvalidParameters.new(:image_url) if !image_url

        image = Upload.find_by(sha1: Upload.sha1_from_long_url(image_url))

        if image.secure?
          url = Upload.signed_url_from_secure_uploads_url(image_url)
        else
          url = UrlHelper.absolute(image_url)
        end

        hijack do
          caption = DiscourseAi::AiHelper::Assistant.new.generate_image_caption(url, current_user)
          render json: { caption: caption }, status: 200
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
