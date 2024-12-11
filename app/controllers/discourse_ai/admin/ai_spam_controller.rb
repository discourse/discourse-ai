# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiSpamController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def show
        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      def update
        updated_params = {}

        updated_params[:llm_model_id] = allowed_params[:llm_model_id] if allowed_params.key?(
          :llm_model_id,
        )

        updated_params[:data] = {
          custom_instructions: allowed_params[:custom_instructions],
        } if allowed_params.key?(:custom_instructions)

        if updated_params.present?
          # not using upsert cause we will not get the correct validation errors
          if AiModerationSetting.spam
            AiModerationSetting.spam.update!(updated_params)
          else
            AiModerationSetting.create!(updated_params.merge(setting_type: :spam))
          end
        end

        is_enabled = ActiveModel::Type::Boolean.new.cast(allowed_params[:is_enabled])

        if allowed_params.key?(:is_enabled)
          if is_enabled && !AiModerationSetting.spam&.llm_model_id
            return(
              render_json_error(
                I18n.t("discourse_ai.llm.configuration.must_select_model"),
                status: 422,
              )
            )
          end

          SiteSetting.ai_spam_detection_enabled = is_enabled
        end

        render json: AiSpamSerializer.new(spam_config, root: false)
      end

      private

      def allowed_params
        params.permit(:is_enabled, :llm_model_id, :custom_instructions)
      end

      def spam_config
        spam_config = {
          enabled: SiteSetting.ai_spam_detection_enabled,
          settings: AiModerationSetting.spam,
        }

        spam_config[:stats] = DiscourseAi::AiModeration::SpamReport.generate(min_date: 1.week.ago)

        if spam_config[:stats].scanned_count > 0
          spam_config[
            :flagging_username
          ] = DiscourseAi::AiModeration::SpamScanner.flagging_user&.username
        end
        spam_config
      end
    end
  end
end
