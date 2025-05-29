# frozen_string_literal: true

RSpec.describe DiscourseAi::InferredConcepts::Applier do
  fab!(:topic) { Fabricate(:topic, title: "Ruby Programming Tutorial") }
  fab!(:post) { Fabricate(:post, raw: "This post is about advanced testing techniques") }
  fab!(:user) { Fabricate(:user, username: "dev_user") }
  fab!(:concept1) { Fabricate(:inferred_concept, name: "programming") }
  fab!(:concept2) { Fabricate(:inferred_concept, name: "testing") }
  fab!(:llm_model) { Fabricate(:fake_model) }

  before do
    SiteSetting.inferred_concepts_match_persona = -1
    SiteSetting.inferred_concepts_enabled = true

    # Set up the post's user
    post.update!(user: user)
  end

  describe ".apply_to_topic" do
    it "does nothing for blank topic or concepts" do
      expect { described_class.apply_to_topic(nil, [concept1]) }.not_to raise_error
      expect { described_class.apply_to_topic(topic, []) }.not_to raise_error
      expect { described_class.apply_to_topic(topic, nil) }.not_to raise_error
    end

    it "associates concepts with topic" do
      described_class.apply_to_topic(topic, [concept1, concept2])

      expect(topic.inferred_concepts).to include(concept1, concept2)
      expect(concept1.topics).to include(topic)
      expect(concept2.topics).to include(topic)
    end
  end

  describe ".apply_to_post" do
    it "does nothing for blank post or concepts" do
      expect { described_class.apply_to_post(nil, [concept1]) }.not_to raise_error
      expect { described_class.apply_to_post(post, []) }.not_to raise_error
      expect { described_class.apply_to_post(post, nil) }.not_to raise_error
    end

    it "associates concepts with post" do
      described_class.apply_to_post(post, [concept1, concept2])

      expect(post.inferred_concepts).to include(concept1, concept2)
      expect(concept1.posts).to include(post)
      expect(concept2.posts).to include(post)
    end
  end

  describe ".topic_content_for_analysis" do
    it "returns empty string for blank topic" do
      expect(described_class.topic_content_for_analysis(nil)).to eq("")
    end

    it "extracts title and posts content" do
      # Create additional posts for the topic
      post1 = Fabricate(:post, topic: topic, post_number: 1, raw: "First post content", user: user)
      post2 = Fabricate(:post, topic: topic, post_number: 2, raw: "Second post content", user: user)

      content = described_class.topic_content_for_analysis(topic)

      expect(content).to include(topic.title)
      expect(content).to include("First post content")
      expect(content).to include("Second post content")
      expect(content).to include(user.username)
      expect(content).to include("1)")
      expect(content).to include("2)")
    end

    it "limits to first 10 posts" do
      # Create 12 posts for the topic
      12.times { |i| Fabricate(:post, topic: topic, post_number: i + 1, user: user) }

      expect(Post).to receive(:where).with(topic_id: topic.id).and_call_original
      expect_any_instance_of(ActiveRecord::Relation).to receive(:limit).with(10).and_call_original

      described_class.topic_content_for_analysis(topic)
    end
  end

  describe ".post_content_for_analysis" do
    it "returns empty string for blank post" do
      expect(described_class.post_content_for_analysis(nil)).to eq("")
    end

    it "extracts post content with topic context" do
      content = described_class.post_content_for_analysis(post)

      expect(content).to include(post.topic.title)
      expect(content).to include(post.raw)
      expect(content).to include(post.user.username)
      expect(content).to include("Topic:")
      expect(content).to include("Post by")
    end

    it "handles post without topic" do
      # Mock the post to return nil for topic
      allow(post).to receive(:topic).and_return(nil)

      content = described_class.post_content_for_analysis(post)

      expect(content).to include(post.raw)
      expect(content).to include(post.user.username)
      expect(content).to include("Topic: ")
    end
  end

  describe ".match_existing_concepts" do
    before do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:list_concepts).and_return(
        %w[programming testing ruby],
      )
    end

    it "returns empty array for blank topic" do
      expect(described_class.match_existing_concepts(nil)).to eq([])
    end

    it "returns empty array when no existing concepts" do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:list_concepts).and_return([])

      result = described_class.match_existing_concepts(topic)
      expect(result).to eq([])
    end

    it "matches concepts and applies them to topic" do
      expect(described_class).to receive(:topic_content_for_analysis).with(topic).and_return(
        "content about programming",
      )

      expect(described_class).to receive(:match_concepts_to_content).with(
        "content about programming",
        %w[programming testing ruby],
      ).and_return(["programming"])

      expect(InferredConcept).to receive(:where).with(name: ["programming"]).and_return([concept1])

      expect(described_class).to receive(:apply_to_topic).with(topic, [concept1])

      result = described_class.match_existing_concepts(topic)
      expect(result).to eq([concept1])
    end
  end

  describe ".match_existing_concepts_for_post" do
    before do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:list_concepts).and_return(
        %w[programming testing ruby],
      )
    end

    it "returns empty array for blank post" do
      expect(described_class.match_existing_concepts_for_post(nil)).to eq([])
    end

    it "returns empty array when no existing concepts" do
      allow(DiscourseAi::InferredConcepts::Manager).to receive(:list_concepts).and_return([])

      result = described_class.match_existing_concepts_for_post(post)
      expect(result).to eq([])
    end

    it "matches concepts and applies them to post" do
      expect(described_class).to receive(:post_content_for_analysis).with(post).and_return(
        "content about testing",
      )

      expect(described_class).to receive(:match_concepts_to_content).with(
        "content about testing",
        %w[programming testing ruby],
      ).and_return(["testing"])

      expect(InferredConcept).to receive(:where).with(name: ["testing"]).and_return([concept2])

      expect(described_class).to receive(:apply_to_post).with(post, [concept2])

      result = described_class.match_existing_concepts_for_post(post)
      expect(result).to eq([concept2])
    end
  end

  describe ".match_concepts_to_content" do
    it "returns empty array for blank content or concept list" do
      expect(described_class.match_concepts_to_content("", ["concept1"])).to eq([])
      expect(described_class.match_concepts_to_content(nil, ["concept1"])).to eq([])
      expect(described_class.match_concepts_to_content("content", [])).to eq([])
      expect(described_class.match_concepts_to_content("content", nil)).to eq([])
    end

    it "uses ConceptMatcher persona to match concepts" do
      content = "This is about Ruby programming"
      concept_list = %w[programming testing ruby]
      expected_response = [['{"matching_concepts": ["programming", "ruby"]}']]

      persona_class_double = double("ConceptMatcherClass")
      persona_double = double("ConceptMatcher")
      bot_double = double("Bot")

      expect(AiPersona).to receive_message_chain(:all_personas, :find).and_return(
        persona_class_double,
      )
      expect(persona_class_double).to receive(:new).and_return(persona_double)
      expect(persona_double).to receive(:class).and_return(persona_class_double)
      expect(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      expect(LlmModel).to receive(:find).and_return(llm_model)
      expect(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      expect(bot_double).to receive(:reply).and_return(expected_response)

      result = described_class.match_concepts_to_content(content, concept_list)
      expect(result).to eq(%w[programming ruby])
    end

    it "handles invalid JSON response gracefully" do
      content = "Test content"
      concept_list = ["concept1"]
      invalid_response = [["invalid json"]]

      persona_class_double = double("ConceptMatcherClass")
      persona_double = double("ConceptMatcher")
      bot_double = double("Bot")

      expect(AiPersona).to receive_message_chain(:all_personas, :find).and_return(
        persona_class_double,
      )
      expect(persona_class_double).to receive(:new).and_return(persona_double)
      expect(persona_double).to receive(:class).and_return(persona_class_double)
      expect(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      expect(LlmModel).to receive(:find).and_return(llm_model)
      expect(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      expect(bot_double).to receive(:reply).and_return(invalid_response)

      expect { described_class.match_concepts_to_content(content, concept_list) }.to raise_error(
        JSON::ParserError,
      )
    end

    it "returns empty array when no matching concepts found" do
      content = "This is about something else"
      concept_list = %w[programming testing]
      expected_response = [['{"matching_concepts": []}']]

      persona_class_double = double("ConceptMatcherClass")
      persona_double = double("ConceptMatcher")
      bot_double = double("Bot")

      expect(AiPersona).to receive_message_chain(:all_personas, :find).and_return(
        persona_class_double,
      )
      expect(persona_class_double).to receive(:new).and_return(persona_double)
      expect(persona_double).to receive(:class).and_return(persona_class_double)
      expect(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      expect(LlmModel).to receive(:find).and_return(llm_model)
      expect(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      expect(bot_double).to receive(:reply).and_return(expected_response)

      result = described_class.match_concepts_to_content(content, concept_list)
      expect(result).to eq([])
    end

    it "handles missing matching_concepts key in response" do
      content = "Test content"
      concept_list = ["concept1"]
      expected_response = [['{"other_key": ["value"]}']]

      persona_class_double = double("ConceptMatcherClass")
      persona_double = double("ConceptMatcher")
      bot_double = double("Bot")

      expect(AiPersona).to receive_message_chain(:all_personas, :find).and_return(
        persona_class_double,
      )
      expect(persona_class_double).to receive(:new).and_return(persona_double)
      expect(persona_double).to receive(:class).and_return(persona_class_double)
      expect(persona_class_double).to receive(:default_llm_id).and_return(llm_model.id)
      expect(LlmModel).to receive(:find).and_return(llm_model)
      expect(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
      expect(bot_double).to receive(:reply).and_return(expected_response)

      result = described_class.match_concepts_to_content(content, concept_list)
      expect(result).to eq([])
    end
  end
end
