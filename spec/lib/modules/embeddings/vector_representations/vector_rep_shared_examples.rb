# frozen_string_literal: true

RSpec.shared_examples "generates and store embedding using with vector representation" do
  before { @expected_embedding = [0.0038493] * vector_rep.dimensions }

  describe "#vector_from" do
    it "creates a vector from a given string" do
      text = "This is a piece of text"
      stub_vector_mapping(text, @expected_embedding)

      expect(vector_rep.vector_from(text)).to eq(@expected_embedding)
    end
  end

  describe "#generate_representation_from" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }
    fab!(:post2) { Fabricate(:post, post_number: 2, topic: topic) }

    it "creates a vector from a topic and stores it in the database" do
      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, @expected_embedding)

      vector_rep.generate_representation_from(topic)

      expect(vector_rep.topic_id_from_representation(@expected_embedding)).to eq(topic.id)
    end

    it "creates a vector from a post and stores it in the database" do
      text =
        truncation.prepare_text_from(
          post2,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, @expected_embedding)

      vector_rep.generate_representation_from(post)

      expect(vector_rep.post_id_from_representation(@expected_embedding)).to eq(post.id)
    end
  end

  describe "#asymmetric_topics_similarity_search" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }

    it "finds IDs of similar topics with a given embedding" do
      similar_vector = [0.0038494] * vector_rep.dimensions
      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, @expected_embedding)
      vector_rep.generate_representation_from(topic)

      expect(
        vector_rep.asymmetric_topics_similarity_search(similar_vector, limit: 1, offset: 0),
      ).to contain_exactly(topic.id)
    end
  end
end
