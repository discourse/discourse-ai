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
    select_kit = PageObjects::Components::SelectKit.new(".ai-embedding-editor__presets")
    select_kit.expand
    select_kit.select_row_by_value(preset)
    find(".ai-embedding-editor__next").click
    find("input.ai-embedding-editor__api-key").fill_in(with: api_key)
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
    select_kit = PageObjects::Components::SelectKit.new(".ai-embedding-editor__presets")
    select_kit.expand
    select_kit.select_row_by_value("manual")
    find(".ai-embedding-editor__next").click

    find("input.ai-embedding-editor__display-name").fill_in(with: "OpenAI's text-embedding-3-small")

    select_kit = PageObjects::Components::SelectKit.new(".ai-embedding-editor__provider")
    select_kit.expand
    select_kit.select_row_by_value(EmbeddingDefinition::OPEN_AI)

    find("input.ai-embedding-editor__url").fill_in(with: "https://api.openai.com/v1/embeddings")
    find("input.ai-embedding-editor__api-key").fill_in(with: api_key)

    select_kit = PageObjects::Components::SelectKit.new(".ai-embedding-editor__tokenizer")
    select_kit.expand
    select_kit.select_row_by_value("DiscourseAi::Tokenizer::OpenAiTokenizer")

    find("input.ai-embedding-editor__dimensions").fill_in(with: 1536)
    find("input.ai-embedding-editor__max_sequence_length").fill_in(with: 8191)

    select_kit = PageObjects::Components::SelectKit.new(".ai-embedding-editor__distance_functions")
    select_kit.expand
    select_kit.select_row_by_value("<=>")
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
  end
end
