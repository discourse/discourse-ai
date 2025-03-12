# frozen_string_literal: true

RSpec.describe "Managing Embeddings configurations", type: :system, js: true do
  fab!(:admin)
  let(:page_header) { PageObjects::Components::DPageHeader.new }

  before { sign_in(admin) }

  it "correctly sets defaults" do
    preset = "text-embedding-3-small"
    api_key = "abcd"

    visit "/admin/plugins/discourse-ai/ai-embeddings"

    find(".ai-embeddings-list-editor__new-button").click()

    find("[data-preset-id='text-embedding-3-small'] button").click()

    find(".form-kit__control-password").fill_in(with: api_key)
    find(".ai-embedding-editor__save").click()

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-embeddings")

    embedding_def = EmbeddingDefinition.order(:id).last
    expect(embedding_def.api_key).to eq(api_key)

    preset = EmbeddingDefinition.presets.find { |p| p[:preset_id] == preset }

    expect(embedding_def.display_name).to eq(preset[:display_name])
    expect(embedding_def.url).to eq(preset[:url])
    expect(embedding_def.tokenizer_class).to eq(preset[:tokenizer_class])
    expect(embedding_def.dimensions).to eq(preset[:dimensions])
    expect(embedding_def.max_sequence_length).to eq(preset[:max_sequence_length])
    expect(embedding_def.pg_function).to eq(preset[:pg_function])
    expect(embedding_def.provider).to eq(preset[:provider])
    expect(embedding_def.provider_params.symbolize_keys).to eq(preset[:provider_params])
  end

  it "supports manual config" do
    api_key = "abcd"

    visit "/admin/plugins/discourse-ai/ai-embeddings"

    find(".ai-embeddings-list-editor__new-button").click()

    find("[data-preset-id='manual'] button").click()

    find("#control-display_name input").fill_in(with: "text-embedding-3-small")

    find("#control-provider select").select(EmbeddingDefinition::OPEN_AI)

    find("#control-url input").fill_in(with: "https://api.openai.com/v1/embeddings")
    find("#control-api_key input").fill_in(with: api_key)

    find("#control-tokenizer_class select").select("OpenAiTokenizer")

    embed_prefix = "On creation:"
    search_prefix = "On search:"
    find("#control-embed_prompt textarea").fill_in(with: embed_prefix)
    find("#control-search_prompt textarea").fill_in(with: search_prefix)
    find("#control-dimensions input").fill_in(with: 1536)
    find("#control-max_sequence_length input").fill_in(with: 8191)

    find("#control-pg_function select").select("Cosine distance")

    find(".ai-embedding-editor__save").click()

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-embeddings")

    embedding_def = EmbeddingDefinition.order(:id).last
    expect(embedding_def.api_key).to eq(api_key)

    preset = EmbeddingDefinition.presets.find { |p| p[:preset_id] == "text-embedding-3-small" }

    expect(embedding_def.display_name).to eq(preset[:display_name])
    expect(embedding_def.url).to eq(preset[:url])
    expect(embedding_def.tokenizer_class).to eq(preset[:tokenizer_class])
    expect(embedding_def.dimensions).to eq(preset[:dimensions])
    expect(embedding_def.max_sequence_length).to eq(preset[:max_sequence_length])
    expect(embedding_def.pg_function).to eq(preset[:pg_function])
    expect(embedding_def.provider).to eq(preset[:provider])
    expect(embedding_def.embed_prompt).to eq(embed_prefix)
    expect(embedding_def.search_prompt).to eq(search_prefix)
  end
end
