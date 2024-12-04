# frozen_string_literal: true

RSpec.shared_examples "generates and store embedding using with vector representation" do
  let(:expected_embedding_1) { [0.0038493] * vector_rep.dimensions }
  let(:expected_embedding_2) { [0.0037684] * vector_rep.dimensions }

  describe "#vector_from" do
    it "creates a vector from a given string" do
      text = "This is a piece of text"
      stub_vector_mapping(text, expected_embedding_1)

      expect(vector_rep.vector_from(text)).to eq(expected_embedding_1)
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
      stub_vector_mapping(text, expected_embedding_1)

      vector_rep.generate_representation_from(topic)

      expect(vector_rep.topic_id_from_representation(expected_embedding_1)).to eq(topic.id)
    end

    it "creates a vector from a post and stores it in the database" do
      text =
        truncation.prepare_text_from(
          post2,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, expected_embedding_1)

      vector_rep.generate_representation_from(post)

      expect(vector_rep.post_id_from_representation(expected_embedding_1)).to eq(post.id)
    end
  end

  describe "#gen_bulk_reprensentations" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, post_number: 1, topic: topic) }
    fab!(:post2) { Fabricate(:post, post_number: 2, topic: topic) }

    fab!(:topic_2) { Fabricate(:topic) }
    fab!(:post_2_1) { Fabricate(:post, post_number: 1, topic: topic_2) }
    fab!(:post_2_2) { Fabricate(:post, post_number: 2, topic: topic_2) }

    it "creates a vector for each object in the relation" do
      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )

      text2 =
        truncation.prepare_text_from(
          topic_2,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )

      stub_vector_mapping(text, expected_embedding_1)
      stub_vector_mapping(text2, expected_embedding_2)

      vector_rep.gen_bulk_reprensentations(Topic.where(id: [topic.id, topic_2.id]))

      expect(vector_rep.topic_id_from_representation(expected_embedding_1)).to eq(topic.id)
      expect(vector_rep.topic_id_from_representation(expected_embedding_1)).to eq(topic.id)
    end

    it "does nothing if passed record has no content" do
      expect { vector_rep.gen_bulk_reprensentations([Topic.new]) }.not_to raise_error
    end

    it "doesn't ask for a new embedding if digest is the same" do
      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, expected_embedding_1)

      original_vector_gen = Time.zone.parse("2021-06-04 10:00")

      freeze_time(original_vector_gen) do
        vector_rep.gen_bulk_reprensentations(Topic.where(id: [topic.id]))
      end
      # check vector exists
      expect(vector_rep.topic_id_from_representation(expected_embedding_1)).to eq(topic.id)

      vector_rep.gen_bulk_reprensentations(Topic.where(id: [topic.id]))
      last_update =
        DB.query_single(
          "SELECT updated_at FROM #{vector_rep.topic_table_name} WHERE topic_id = #{topic.id} LIMIT 1",
        ).first

      expect(last_update).to eq(original_vector_gen)
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
      stub_vector_mapping(text, expected_embedding_1)
      vector_rep.generate_representation_from(topic)

      expect(
        vector_rep.asymmetric_topics_similarity_search(similar_vector, limit: 1, offset: 0),
      ).to contain_exactly(topic.id)
    end

    it "can exclude categories" do
      similar_vector = [0.0038494] * vector_rep.dimensions
      text =
        truncation.prepare_text_from(
          topic,
          vector_rep.tokenizer,
          vector_rep.max_sequence_length - 2,
        )
      stub_vector_mapping(text, expected_embedding_1)
      vector_rep.generate_representation_from(topic)

      expect(
        vector_rep.asymmetric_topics_similarity_search(
          similar_vector,
          limit: 1,
          offset: 0,
          exclude_category_ids: [topic.category_id],
        ),
      ).to be_empty

      child_category = Fabricate(:category, parent_category_id: topic.category_id)
      topic.update!(category_id: child_category.id)

      expect(
        vector_rep.asymmetric_topics_similarity_search(
          similar_vector,
          limit: 1,
          offset: 0,
          exclude_category_ids: [topic.category_id],
        ),
      ).to be_empty
    end
  end
end
