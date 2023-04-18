# frozen_string_literal: true

require "rails_helper"

describe DiscourseAi::Tokenizer do
  describe "#size" do
    describe "returns a token count" do
      it "for a single word" do
        expect(DiscourseAi::Tokenizer.size("hello")).to eq(3)
      end

      it "for a sentence" do
        expect(DiscourseAi::Tokenizer.size("hello world")).to eq(4)
      end

      it "for a sentence with punctuation" do
        expect(DiscourseAi::Tokenizer.size("hello, world!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization" do
        expect(DiscourseAi::Tokenizer.size("Hello, World!")).to eq(6)
      end

      it "for a sentence with punctuation and capitalization and numbers" do
        expect(DiscourseAi::Tokenizer.size("Hello, World! 123")).to eq(7)
      end
    end
  end

  describe "#tokenizer" do
    it "returns a tokenizer" do
      expect(DiscourseAi::Tokenizer.tokenizer).to be_a(Tokenizers::Tokenizer)
    end

    it "returns the same tokenizer" do
      expect(DiscourseAi::Tokenizer.tokenizer).to eq(DiscourseAi::Tokenizer.tokenizer)
    end
  end
end
