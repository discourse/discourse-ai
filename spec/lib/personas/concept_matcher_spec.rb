# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ConceptMatcher do
  let(:persona) { described_class.new }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    let(:prompt) { persona.system_prompt }

    it "explains the concept matching task" do
      expect(prompt).to include("advanced concept matching system")
      expect(prompt).to include("determines which concepts from a provided list are relevant")
    end

    it "provides matching guidelines" do
      expect(prompt).to include("Only select concepts that are clearly relevant")
      expect(prompt).to include("content must substantially discuss or relate")
      expect(prompt).to include("Superficial mentions are not enough")
      expect(prompt).to include("Be precise and selective")
      expect(prompt).to include("Consider both explicit mentions and implicit discussions")
    end

    it "emphasizes exact concept matching" do
      expect(prompt).to include("Only select from the exact concepts in the provided list")
      expect(prompt).to include("do not add new concepts")
      expect(prompt).to include("If no concepts from the list match")
    end

    it "includes placeholder for concept list" do
      expect(prompt).to include("{inferred_concepts}")
      expect(prompt).to include("The list of available concepts is:")
    end

    it "specifies output format" do
      expect(prompt).to include("matching_concepts")
      expect(prompt).to include("<o>")
      expect(prompt).to include('{"matching_concepts": ["concept1", "concept3", "concept5"]}')
      expect(prompt).to include("</o>")
    end

    it "emphasizes language preservation" do
      expect(prompt).to include("original language of the text")
    end

    it "handles empty matches" do
      expect(prompt).to include("return an empty array")
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = persona.response_format

      expect(format).to eq([{ "key" => "matching_concepts", "type" => "array" }])
    end
  end

  describe "matching criteria" do
    let(:prompt) { persona.system_prompt }

    it "requires substantial discussion" do
      expect(prompt).to include("substantially discuss or relate to the concept")
    end

    it "rejects superficial mentions" do
      expect(prompt).to include("Superficial mentions are not enough")
    end

    it "emphasizes precision" do
      expect(prompt).to include("precise and selective")
      expect(prompt).to include("tangentially related")
    end

    it "considers implicit discussions" do
      expect(prompt).to include("explicit mentions and implicit discussions")
    end

    it "restricts to provided list only" do
      expect(prompt).to include("exact concepts in the provided list")
      expect(prompt).to include("do not add new concepts")
    end
  end
end
