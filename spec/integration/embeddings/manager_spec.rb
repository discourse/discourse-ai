# frozen_string_literal: true

require_relative "../../support/embeddings_generation_stubs"

RSpec.describe DiscourseAi::Embeddings::Manager do
  let(:user) { Fabricate(:user) }
  let(:expected_embedding) do
    JSON.parse(
      File.read("#{Rails.root}/plugins/discourse-ai/spec/fixtures/embeddings/embedding.txt"),
    )
  end
  let(:discourse_model) { "all-mpnet-base-v2" }

  before do
    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_model = "all-mpnet-base-v2"
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
    Jobs.run_immediately!
  end

  it "generates embeddings for new topics automatically" do
    pc =
      PostCreator.new(
        user,
        raw: "this is the new content for my topic",
        title: "this is my new topic title",
      )
    input =
      "This is my new topic title\n\nUncategorized\n\n\n\nthis is the new content for my topic\n\n"
    EmbeddingsGenerationStubs.discourse_service(discourse_model, input, expected_embedding)
    post = pc.create
    manager = DiscourseAi::Embeddings::Manager.new(post.topic)

    embeddings =
      DB.query_single(
        "SELECT embeddings FROM #{manager.topic_embeddings_table} WHERE topic_id = #{post.topic.id}",
      ).first

    expect(embeddings.split(",")[1].to_f).to be_within(0.0001).of(expected_embedding[1])
    expect(embeddings.split(",")[13].to_f).to be_within(0.0001).of(expected_embedding[13])
    expect(embeddings.split(",")[135].to_f).to be_within(0.0001).of(expected_embedding[135])
  end
end
