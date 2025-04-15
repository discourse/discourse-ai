# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::StructuredOutput do
  subject(:structured_output) { described_class.new(%i[message status]) }

  describe "Parsing structured output on the fly" do
    it "acts as a buffer for an streamed JSON" do
      chunks = ["{\"message\": \"Line 1\\", "nLine 2\", \"status\": \"o", "\\\"k\\\"\"}"]

      structured_output << chunks[0]

      expect(structured_output.full_output[:status]).to be_empty
      expect(structured_output.full_output[:message]).to eq("Line 1")
      expect(structured_output.last_chunk_output[:status]).to be_empty
      expect(structured_output.last_chunk_output[:message]).to eq("Line 1")

      structured_output << chunks[1]

      expect(structured_output.full_output[:status]).to eq("o")
      expect(structured_output.full_output[:message]).to eq("Line 1\nLine 2")
      expect(structured_output.last_chunk_output[:status]).to eq("o")
      expect(structured_output.last_chunk_output[:message]).to eq("\nLine 2")

      structured_output << chunks[2]

      expect(structured_output.full_output[:status]).to eq("o\"k\"")
      expect(structured_output.full_output[:message]).to eq("Line 1\nLine 2")
      expect(structured_output.last_chunk_output[:status]).to eq("\"k\"")
      expect(structured_output.last_chunk_output[:message]).to be_empty
    end
  end
end
