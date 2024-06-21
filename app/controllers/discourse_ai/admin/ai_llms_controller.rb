# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLlmsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        llms = LlmModel.all.order(:display_name)

        render json: {
                 ai_llms:
                   ActiveModel::ArraySerializer.new(
                     llms,
                     each_serializer: LlmModelSerializer,
                     root: false,
                   ).as_json,
                 meta: {
                   presets: DiscourseAi::Completions::Llm.presets,
                   providers: DiscourseAi::Completions::Llm.provider_names,
                   tokenizers:
                     DiscourseAi::Completions::Llm.tokenizer_names.map { |tn|
                       { id: tn, name: tn.split("::").last }
                     },
                 },
               }
      end

      def show
        llm_model = LlmModel.find(params[:id])
        render json: LlmModelSerializer.new(llm_model)
      end

      def create
        llm_model = LlmModel.new(ai_llm_params)
        if llm_model.save
          render json: { ai_persona: llm_model }, status: :created
        else
          render_json_error llm_model
        end
      end

      def update
        llm_model = LlmModel.find(params[:id])

        if llm_model.update(ai_llm_params)
          llm_model.toggle_companion_user
          render json: llm_model
        else
          render_json_error llm_model
        end
      end

      def destroy
        llm_model = LlmModel.find(params[:id])

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

      def ai_llm_params
        params.require(:ai_llm).permit(
          :display_name,
          :name,
          :provider,
          :tokenizer,
          :max_prompt_tokens,
          :url,
          :api_key,
          :enabled_chat_bot,
        )
      end
    end
  end
end
