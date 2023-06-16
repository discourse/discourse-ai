# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Tokenizer::BertTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a single word" do
        expect(described_class.size("hello")).to eq(3)
      end

      it "for a sentence" do
        expect(described_class.size("hello world")).to eq(4)
      end

      it "for a sentence with punctuation" do
        expect(described_class.size("hello, world!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization" do
        expect(described_class.size("Hello, World!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#tokenizer" do
    it "returns a tokenizer" do
      expect(described_class.tokenizer).to be_a(Tokenizers::Tokenizer)
    end

    it "returns the same tokenizer" do
      expect(described_class.tokenizer).to eq(described_class.tokenizer)
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar")
    end
  end
end

describe DiscourseAi::Tokenizer::AnthropicTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(5)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar baz")
    end
  end
end

describe DiscourseAi::Tokenizer::OpenAiTokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a sentence with punctuation and capitalization and numbers" do
        expect(described_class.size("Hello, World! 123")).to eq(6)
      end
    end
  end

  describe "#truncate" do
    it "truncates a sentence" do
      sentence = "foo bar baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 3)).to eq("foo bar baz")
    end

    it "truncates a sentence sucesfully at a multibyte unicode character" do
      sentence = "foo bar 👨🏿‍👩🏿‍👧🏿‍👧🏿 baz qux quux corge grault garply waldo fred plugh xyzzy thud"
      expect(described_class.truncate(sentence, 7)).to eq("foo bar 👨🏿")
    end
  end
end
