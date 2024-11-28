# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::SemanticCategorizer do
  fab!(:user)
  fab!(:muted_category) { Fabricate(:category) }
  fab!(:category_mute) do
    CategoryUser.create!(
      user: user,
      category: muted_category,
      notification_level: CategoryUser.notification_levels[:muted],
    )
  end
  fab!(:muted_topic) { Fabricate(:topic, category: muted_category) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }

  let(:truncation) { DiscourseAi::Embeddings::Strategies::Truncation.new }
  let(:vector_rep) do
    DiscourseAi::Embeddings::VectorRepresentations::Base.current_representation(truncation)
  end
  let(:categorizer) { DiscourseAi::AiHelper::SemanticCategorizer.new({ text: "hello" }, user) }
  let(:expected_embedding) { [0.0038493] * vector_rep.dimensions }

  before do
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_discourse_service_api_endpoint = "http://test.com"
    SiteSetting.ai_embeddings_model = "bge-large-en"

    WebMock.stub_request(
      :post,
      "#{SiteSetting.ai_embeddings_discourse_service_api_endpoint}/api/v1/classify",
    ).to_return(status: 200, body: JSON.dump(expected_embedding))

    vector_rep.generate_representation_from(topic)
    vector_rep.generate_representation_from(muted_topic)
  end

  it "respects user muted categories when making suggestions" do
    category_ids = categorizer.categories.map { |c| c[:id] }
    expect(category_ids).not_to include(muted_category.id)
    expect(category_ids).to include(category.id)
  end
end
