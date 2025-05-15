# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::StructuredOutput do
  subject(:structured_output) do
    described_class.new(
      {
        message: {
          type: "string",
        },
        bool: {
          type: "boolean",
        },
        number: {
          type: "integer",
        },
        status: {
          type: "string",
        },
      },
    )
  end

  describe "Parsing structured output on the fly" do
    it "acts as a buffer for an streamed JSON" do
      chunks = [
        +"{\"message\": \"Line 1\\n",
        +"Line 2\\n",
        +"Line 3\", ",
        +"\"bool\": true,",
        +"\"number\": 4",
        +"2,",
        +"\"status\": \"o",
        +"\\\"k\\\"\"}",
      ]

      structured_output << chunks[0]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 1\n")

      structured_output << chunks[1]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 2\n")

      structured_output << chunks[2]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 3")

      structured_output << chunks[3]
      expect(structured_output.read_buffered_property(:bool)).to eq(true)

      # Waiting for number to be fully buffered.
      structured_output << chunks[4]
      expect(structured_output.read_buffered_property(:bool)).to eq(true)
      expect(structured_output.read_buffered_property(:number)).to be_nil

      structured_output << chunks[5]
      expect(structured_output.read_buffered_property(:number)).to eq(42)

      structured_output << chunks[6]
      expect(structured_output.read_buffered_property(:number)).to eq(42)
      expect(structured_output.read_buffered_property(:bool)).to eq(true)
      expect(structured_output.read_buffered_property(:status)).to eq("o")

      structured_output << chunks[7]
      expect(structured_output.read_buffered_property(:status)).to eq("\"k\"")

      # No partial string left to read.
      expect(structured_output.read_buffered_property(:status)).to eq("")
    end
  end

  describe "dealing with non-JSON responses" do
    it "treat it as plain text once we determined it's invalid JSON" do
      chunks = [+"I'm not", +"a", +"JSON :)"]

      structured_output << chunks[0]
      expect(structured_output.read_buffered_property(nil)).to eq("I'm not")

      structured_output << chunks[1]
      expect(structured_output.read_buffered_property(nil)).to eq("a")

      structured_output << chunks[2]
      expect(structured_output.read_buffered_property(nil)).to eq("JSON :)")
    end
  end
end
