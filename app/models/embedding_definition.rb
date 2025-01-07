# frozen_string_literal: true

class EmbeddingDefinition < ActiveRecord::Base
  CLOUDFLARE = "cloudflare"
  DISCOURSE = "discourse"
  HUGGING_FACE = "hugging_face"
  OPEN_AI = "open_ai"
  GEMINI = "gemini"

  class << self
    def provider_names
      [CLOUDFLARE, DISCOURSE, HUGGING_FACE, OPEN_AI, GEMINI]
    end

    def tokenizer_names
      [
        DiscourseAi::Tokenizer::AllMpnetBaseV2Tokenizer,
        DiscourseAi::Tokenizer::BgeLargeEnTokenizer,
        DiscourseAi::Tokenizer::BgeM3Tokenizer,
        DiscourseAi::Tokenizer::OpenAiTokenizer,
        DiscourseAi::Tokenizer::MultilingualE5LargeTokenizer,
        DiscourseAi::Tokenizer::OpenAiTokenizer,
      ].map(&:name)
    end

    def provider_params
      { discourse: { model_name: :text }, open_ai: { model_name: :text } }
    end
  end

  validates :provider, presence: true, inclusion: provider_names
  validates :display_name, presence: true, length: { maximum: 100 }
  validates :tokenizer_class, presence: true, inclusion: tokenizer_names
  validates_presence_of :url, :api_key, :dimensions, :max_sequence_length, :pg_function

  def tokenizer
    tokenizer_class.constantize
  end

  def inference_client
    case provider
    when CLOUDFLARE
      cloudflare_client
    when DISCOURSE
      discourse_client
    when HUGGING_FACE
      hugging_face_client
    when OPEN_AI
      open_ai_client
    when GEMINI
      gemini_client
    else
      raise "Uknown embeddings provider"
    end
  end

  def lookup_custom_param(key)
    provider_params&.dig(key)
  end

  def endpoint_url
    return url if !url.starts_with?("srv://")

    service = DiscourseAi::Utils::DnsSrv.lookup(url.sub("srv://", ""))
    "https://#{service.target}:#{service.port}"
  end

  def prepare_query_text(text, asymetric: false)
    strategy.prepare_query_text(text, self, asymetric: asymetric)
  end

  def prepare_target_text(target)
    strategy.prepare_target_text(target, self)
  end

  def strategy_id
    strategy.id
  end

  def strategy_version
    strategy.version
  end

  private

  def strategy
    @strategy ||= DiscourseAi::Embeddings::Strategies::Truncation.new
  end

  def cloudflare_client
    DiscourseAi::Inference::CloudflareWorkersAi.new(endpoint_url, api_key)
  end

  def discourse_client
    client_url = endpoint_url
    client_url = "#{client_url}/api/v1/classify" if url.starts_with?("srv://")

    DiscourseAi::Inference::DiscourseClassifier.new(
      client_url,
      api_key,
      lookup_custom_param("model_name"),
    )
  end

  def hugging_face_client
    DiscourseAi::Inference::HuggingFaceTextEmbeddings.new(endpoint_url, api_key)
  end

  def open_ai_client
    DiscourseAi::Inference::OpenAiEmbeddings.new(
      endpoint_url,
      api_key,
      lookup_custom_param("model_name"),
      dimensions,
    )
  end

  def gemini_client
    DiscourseAi::Inference::GeminiEmbeddings.new(endpoint_url, api_key)
  end
end

# == Schema Information
#
# Table name: embedding_definitions
#
#  id                  :bigint           not null, primary key
#  display_name        :string           not null
#  dimensions          :integer          not null
#  max_sequence_length :integer          not null
#  version             :integer          default(1), not null
#  pg_function         :string           not null
#  provider            :string           not null
#  tokenizer_class     :string           not null
#  url                 :string           not null
#  api_key             :string
#  provider_params     :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
