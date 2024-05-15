# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiLlmsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        llms = LlmModel.all

        render json: {
                 ai_llms:
                   ActiveModel::ArraySerializer.new(
                     llms,
                     each_serializer: LlmModelSerializer,
                     root: false,
                   ).as_json,
                 meta: {
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
          render json: llm_model
        else
          render_json_error llm_model
        end
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
        )
      end
    end
  end
end
