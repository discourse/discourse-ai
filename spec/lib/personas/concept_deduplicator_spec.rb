# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::ConceptDeduplicator do
  let(:persona) { described_class.new }

  describe ".default_enabled" do
    it "is disabled by default" do
      expect(described_class.default_enabled).to eq(false)
    end
  end

  describe "#system_prompt" do
    let(:prompt) { persona.system_prompt }

    it "explains the deduplication task" do
      expect(prompt).to include("streamline this list by merging entries who are similar")
      expect(prompt).to include("machine-generated tags")
    end

    it "provides step-by-step instructions" do
      expect(prompt).to include("1. Review the entire list")
      expect(prompt).to include("2. Identify and remove any exact duplicates")
      expect(prompt).to include("3. Look for tags that are too specific")
      expect(prompt).to include("4. If there are multiple tags that convey similar concepts")
      expect(prompt).to include("5. Ensure that the remaining tags are relevant")
    end

    it "defines criteria for best tags" do
      expect(prompt).to include("Relevance: How well does the tag describe")
      expect(prompt).to include("Generality: Is the tag specific enough")
      expect(prompt).to include("Clarity: Is the tag easy to understand")
      expect(prompt).to include("Popularity: Would this tag likely be used")
    end

    it "includes example input and output" do
      expect(prompt).to include("Example Input:")
      expect(prompt).to include("AI Bias, AI Bots, AI Ethics")
      expect(prompt).to include("Example Output:")
      expect(prompt).to include("AI, AJAX, API, APK")
    end

    it "specifies output format" do
      expect(prompt).to include("<streamlined_tags>")
      expect(prompt).to include("<o>")
      expect(prompt).to include('"streamlined_tags": ["tag1", "tag3"]')
      expect(prompt).to include("</o>")
    end

    it "emphasizes maintaining essence" do
      expect(prompt).to include("maintaining the essence of the original list")
    end
  end

  describe "#response_format" do
    it "defines correct response format" do
      format = persona.response_format

      expect(format).to eq([{ "key" => "streamlined_tags", "type" => "array" }])
    end
  end

  describe "deduplication guidelines" do
    let(:prompt) { persona.system_prompt }

    it "addresses duplicate removal" do
      expect(prompt).to include("exact duplicates")
    end

    it "addresses specificity concerns" do
      expect(prompt).to include("too specific or niche")
      expect(prompt).to include("more general terms")
    end

    it "addresses similar concept merging" do
      expect(prompt).to include("similar concepts, choose the best one")
    end

    it "emphasizes relevance and utility" do
      expect(prompt).to include("relevant and useful for describing the content")
    end
  end
end
