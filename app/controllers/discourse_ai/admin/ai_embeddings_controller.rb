# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiEmbeddingsController < ::Admin::AdminController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      def index
        embedding_defs = EmbeddingDefinition.all.order(:display_name)

        render json: {
                 ai_embeddings:
                   ActiveModel::ArraySerializer.new(
                     embedding_defs,
                     each_serializer: AiEmbeddingDefinitionSerializer,
                     root: false,
                   ).as_json,
                 meta: {
                   provider_params: EmbeddingDefinition.provider_params,
                   providers: EmbeddingDefinition.provider_names,
                   distance_functions: EmbeddingDefinition.distance_functions,
                   tokenizers:
                     EmbeddingDefinition.tokenizer_names.map { |tn|
                       { id: tn, name: tn.split("::").last }
                     },
                 },
               }
      end

      def new
      end

      def edit
        embedding_def = EmbeddingDefinition.find(params[:id])
        render json: AiEmbeddingDefinitionSerializer.new(embedding_def)
      end

      def create
        embedding_def = EmbeddingDefinition.new(ai_embeddings_params)

        if embedding_def.save
          render json: AiEmbeddingDefinitionSerializer.new(embedding_def), status: :created
        else
          render_json_error embedding_def
        end
      end

      def update
        embedding_def = EmbeddingDefinition.find(params[:id])

        if embedding_def.update(ai_embeddings_params)
          render json: AiEmbeddingDefinitionSerializer.new(embedding_def)
        else
          render_json_error embedding_def
        end
      end

      def destroy
        embedding_def = EmbeddingDefinition.find(params[:id])

        if embedding_def.id == SiteSetting.ai_embeddings_selected_model.to_i
          return render_json_error(I18n.t("discourse_ai.embeddings.delete_failed"), status: 409)
        end

        if embedding_def.destroy
          head :no_content
        else
          render_json_error embedding_def
        end
      end

      def test
        RateLimiter.new(
          current_user,
          "ai_embeddings_test_#{current_user.id}",
          3,
          1.minute,
        ).performed!

        embedding_def = EmbeddingDefinition.new(ai_embeddings_params)
        DiscourseAi::Embeddings::Vector.new(embedding_def).vector_from("this is a test")

        render json: { success: true }
      rescue Net::HTTPBadResponse => e
        render json: { success: false, error: e.message }
      end

      private

      def ai_embeddings_params
        permitted =
          params.require(:ai_embedding).permit(
            :display_name,
            :dimensions,
            :max_sequence_length,
            :pg_function,
            :provider,
            :url,
            :api_key,
            :tokenizer_class,
          )

        extra_field_names = EmbeddingDefinition.provider_params.dig(permitted[:provider]&.to_sym)
        if extra_field_names.present?
          received_prov_params =
            params.dig(:ai_embedding, :provider_params)&.slice(*extra_field_names.keys)

          if received_prov_params.present?
            permitted[:provider_params] = received_prov_params.permit!
          end
        end

        permitted
      end
    end
  end
end
