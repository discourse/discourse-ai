# frozen_string_literal: true

module DiscourseAi
  module Embeddings
    class Model
      AVAILABLE_MODELS_TEMPLATES = {
        "all-mpnet-base-v2" => [768, 384, %i[dot cosine euclidean], %i[symmetric], "discourse"],
        "all-distilroberta-v1" => [768, 512, %i[dot cosine euclidean], %i[symmetric], "discourse"],
        "multi-qa-mpnet-base-dot-v1" => [768, 512, %i[dot], %i[symmetric], "discourse"],
        "paraphrase-multilingual-mpnet-base-v2" => [
          768,
          128,
          %i[cosine],
          %i[symmetric],
          "discourse",
        ],
        "msmarco-distilbert-base-tas-b" => [768, 512, %i[dot], %i[asymmetric], "discourse"],
        "msmarco-distilbert-base-v4" => [768, 512, %i[cosine], %i[asymmetric], "discourse"],
        "instructor-xl" => [768, 512, %i[cosine], %i[symmetric asymmetric], "discourse"],
        "text-embedding-ada-002" => [1536, 2048, %i[cosine], %i[symmetric asymmetric], "openai"],
      }

      SEARCH_FUNCTION_TO_PG_INDEX = {
        dot: "vector_ip_ops",
        cosine: "vector_cosine_ops",
        euclidean: "vector_l2_ops",
      }

      SEARCH_FUNCTION_TO_PG_FUNCTION = { dot: "<#>", cosine: "<=>", euclidean: "<->" }

      class << self
        def instantiate(model_name)
          new(model_name, *AVAILABLE_MODELS_TEMPLATES[model_name])
        end

        def enabled_models
          SiteSetting
            .ai_embeddings_models
            .split("|")
            .map { |model_name| instantiate(model_name.strip) }
        end
      end

      def initialize(name, dimensions, max_sequence_lenght, functions, type, provider)
        @name = name
        @dimensions = dimensions
        @max_sequence_lenght = max_sequence_lenght
        @functions = functions
        @type = type
        @provider = provider
      end

      def generate_embedding(input)
        send("#{provider}_embeddings", input)
      end

      def pg_function
        SEARCH_FUNCTION_TO_PG_FUNCTION[functions.first]
      end

      def pg_index
        SEARCH_FUNCTION_TO_PG_INDEX[functions.first]
      end

      attr_reader :name, :dimensions, :max_sequence_lenght, :functions, :type, :provider

      private

      def discourse_embeddings(input)
        truncated_input = DiscourseAi::Tokenizer::BertTokenizer.truncate(input, max_sequence_lenght)

        if name.start_with?("instructor")
          instructed_input = [
            SiteSetting.ai_embeddings_semantic_related_instruction,
            truncated_input,
          ]
        end

        DiscourseAi::Inference::DiscourseClassifier.perform!(
          "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
          name.to_s,
          instructed_input,
          SiteSetting.ai_embeddings_discourse_service_api_key,
        )
      end

      def openai_embeddings(input)
        truncated_input =
          DiscourseAi::Tokenizer::OpenAiTokenizer.truncate(input, max_sequence_lenght)
        response = DiscourseAi::Inference::OpenAiEmbeddings.perform!(truncated_input)
        response[:data].first[:embedding]
      end
    end
  end
end
