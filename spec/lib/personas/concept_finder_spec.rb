# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ConceptFinder do
  let(:persona) { described_class.new }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    before do
      Fabricate(:inferred_concept, name: "programming")
      Fabricate(:inferred_concept, name: "testing")
      Fabricate(:inferred_concept, name: "ruby")
    end

    it "includes guidelines for concept extraction" do
      prompt = persona.system_prompt

      expect(prompt).to include("advanced concept tagging system")
      expect(prompt).to include("Extract up to 7 concepts")
      expect(prompt).to include("single words or short phrases")
      expect(prompt).to include("substantive topics, themes, technologies")
      expect(prompt).to include("JSON object")
      expect(prompt).to include('"concepts"')
    end

    it "includes existing concepts when available" do
      prompt = persona.system_prompt

      expect(prompt).to include("following concepts already exist")
      expect(prompt).to include("programming")
      expect(prompt).to include("testing")
      expect(prompt).to include("ruby")
      expect(prompt).to include("reuse these existing concepts")
    end

    it "handles empty existing concepts" do
      InferredConcept.destroy_all
      prompt = persona.system_prompt

      expect(prompt).not_to include("following concepts already exist")
      expect(prompt).to include("advanced concept tagging system")
    end

    it "limits existing concepts to 100" do
      expect(DiscourseAi::InferredConcepts::Manager).to receive(:list_concepts).with(
        limit: 100,
      ).and_return(%w[concept1 concept2])

      persona.system_prompt
    end

    it "includes format instructions" do
      prompt = persona.system_prompt

      expect(prompt).to include("<o>")
      expect(prompt).to include('{"concepts": ["concept1", "concept2", "concept3"]}')
      expect(prompt).to include("</o>")
    end

    it "includes language preservation instruction" do
      prompt = persona.system_prompt

      expect(prompt).to include("original language of the text")
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = persona.response_format

      expect(format).to eq(
        [{ "key" => "concepts", "type" => "array", "items" => { "type" => "string" } }],
      )
    end
  end

  describe "prompt quality guidelines" do
    let(:prompt) { persona.system_prompt }

    it "emphasizes avoiding generic terms" do
      expect(prompt).to include('Avoid overly general terms like "discussion" or "question"')
    end

    it "focuses on substantive content" do
      expect(prompt).to include("substantive topics, themes, technologies, methodologies")
    end

    it "limits concept length" do
      expect(prompt).to include("1-3 words maximum")
    end

    it "emphasizes core content relevance" do
      expect(prompt).to include("relevant to the core content")
    end

    it "discourages proper nouns unless they're technologies" do
      expect(prompt).to include(
        "Do not include proper nouns unless they represent key technologies",
      )
    end
  end
end
