# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLlmsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        llms = LlmModel.all.includes(:llm_quotas).order(:display_name)

        render json: {
                 ai_llms:
                   ActiveModel::ArraySerializer.new(
                     llms,
                     each_serializer: LlmModelSerializer,
                     root: false,
                     scope: {
                       llm_usage: DiscourseAi::Configuration::LlmEnumerator.global_usage,
                     },
                   ).as_json,
                 meta: {
                   provider_params: LlmModel.provider_params,
                   presets: DiscourseAi::Completions::Llm.presets,
                   providers: DiscourseAi::Completions::Llm.provider_names,
                   tokenizers:
                     DiscourseAi::Completions::Llm.tokenizer_names.map { |tn|
                       { id: tn, name: tn.split("::").last }
                     },
                 },
               }
      end

      def new
      end

      def edit
        llm_model = LlmModel.find(params[:id])
        render json: LlmModelSerializer.new(llm_model)
      end

      def create
        llm_model = LlmModel.new(ai_llm_params)

        # we could do nested attributes but the mechanics are not ideal leading
        # to lots of complex debugging, this is simpler
        quota_params.each { |quota| llm_model.llm_quotas.build(quota) } if quota_params

        if llm_model.save
          llm_model.toggle_companion_user
          render json: LlmModelSerializer.new(llm_model), status: :created
        else
          render_json_error llm_model
        end
      end

      def update
        llm_model = LlmModel.find(params[:id])

        if params[:ai_llm].key?(:llm_quotas)
          if quota_params
            existing_quota_group_ids = llm_model.llm_quotas.pluck(:group_id)
            new_quota_group_ids = quota_params.map { |q| q[:group_id] }

            llm_model
              .llm_quotas
              .where(group_id: existing_quota_group_ids - new_quota_group_ids)
              .destroy_all

            quota_params.each do |quota_param|
              quota = llm_model.llm_quotas.find_or_initialize_by(group_id: quota_param[:group_id])
              quota.update!(quota_param)
            end
          else
            llm_model.llm_quotas.destroy_all
          end
        end

        if llm_model.seeded?
          return render_json_error(I18n.t("discourse_ai.llm.cannot_edit_builtin"), status: 403)
        end

        if llm_model.update(ai_llm_params(updating: llm_model))
          llm_model.toggle_companion_user
          render json: LlmModelSerializer.new(llm_model)
        else
          render_json_error llm_model
        end
      end

      def destroy
        llm_model = LlmModel.find(params[:id])

        if llm_model.seeded?
          return render_json_error(I18n.t("discourse_ai.llm.cannot_delete_builtin"), status: 403)
        end

        in_use_by = DiscourseAi::Configuration::LlmValidator.new.modules_using(llm_model)

        if !in_use_by.empty?
          return(
            render_json_error(
              I18n.t(
                "discourse_ai.llm.delete_failed",
                settings: in_use_by.join(", "),
                count: in_use_by.length,
              ),
              status: 409,
            )
          )
        end

        # Clean up companion users
        llm_model.enabled_chat_bot = false
        llm_model.toggle_companion_user

        if llm_model.destroy
          head :no_content
        else
          render_json_error llm_model
        end
      end

      def test
        RateLimiter.new(current_user, "llm_test_#{current_user.id}", 3, 1.minute).performed!

        llm_model = LlmModel.new(ai_llm_params)

        DiscourseAi::Configuration::LlmValidator.new.run_test(llm_model)

        render json: { success: true }
      rescue DiscourseAi::Completions::Endpoints::Base::CompletionFailed => e
        render json: { success: false, error: e.message }
      end

      private

      def quota_params
        if params[:ai_llm][:llm_quotas].present?
          params[:ai_llm][:llm_quotas].map do |quota|
            mapped = {}
            mapped[:group_id] = quota[:group_id].to_i
            mapped[:max_tokens] = quota[:max_tokens].to_i if quota[:max_tokens].present?
            mapped[:max_usages] = quota[:max_usages].to_i if quota[:max_usages].present?
            mapped[:duration_seconds] = quota[:duration_seconds].to_i
            mapped
          end
        end
      end

      def ai_llm_params(updating: nil)
        return {} if params[:ai_llm].blank?

        permitted =
          params.require(:ai_llm).permit(
            :display_name,
            :name,
            :provider,
            :tokenizer,
            :max_prompt_tokens,
            :api_key,
            :enabled_chat_bot,
            :vision_enabled,
            :input_cost,
            :cached_input_cost,
            :output_cost,
          )

        provider = updating ? updating.provider : permitted[:provider]
        permit_url = provider != LlmModel::BEDROCK_PROVIDER_NAME

        new_url = params.dig(:ai_llm, :url)
        permitted[:url] = new_url if permit_url && new_url

        extra_field_names = LlmModel.provider_params.dig(provider&.to_sym)
        if extra_field_names.present?
          received_prov_params =
            params.dig(:ai_llm, :provider_params)&.slice(*extra_field_names.keys)

          if received_prov_params.present?
            received_prov_params.each do |pname, value|
              if extra_field_names[pname.to_sym] == :checkbox
                received_prov_params[pname] = ActiveModel::Type::Boolean.new.cast(value)
              end
            end

            permitted[:provider_params] = received_prov_params.permit!
          end
        end

        permitted
      end
    end
  end
end
