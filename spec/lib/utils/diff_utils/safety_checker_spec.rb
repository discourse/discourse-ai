# frozen_string_literal: true

Rspec.describe DiscourseAi::Utils::DiffUtils::SafetyChecker do
  subject { described_class }

  describe ".safe_to_stream?" do
    it "returns the result of instance safe? method" do
      expect(subject.safe_to_stream?("text")).to eq(subject.new("text").safe?)
    end
  end

  describe "#safe?" do
    subject { subject.new(text).safe? }

    context "with safe text" do
      let(:text) { "This is completely normal text with no issues." }
      it { is_expected.to eq(true) }

      context "with complete markdown constructs" do
        let(:text) { "This has [a link](https://example.com) and **bold** and *italic* text." }
        it { is_expected.to eq(true) }
      end

      context "with complete HTML tags" do
        let(:text) { "This has <strong>bold</strong> and <em>italic</em> text." }
        it { is_expected.to eq(true) }
      end

      context "with complete code blocks" do
        let(:text) { "Code block: ```ruby\ndef method\nend\n```" }
        it { is_expected.to eq(true) }
      end

      context "with complete emoji" do
        let(:text) { "I love this :heart: emoji" }
        it { is_expected.to eq(true) }
      end

      context "with complete quote blocks" do
        let(:text) { "Here's a quote: [quote]Something smart[/quote]" }
        it { is_expected.to eq(true) }
      end
    end

    context "with unclosed markdown links" do
      let(:text) { "This has [a link(" }
      it { is_expected.to eq(false) }

      context "with open bracket but no close bracket" do
        let(:text) { "This has [a link but missing closing bracket" }
        it { is_expected.to eq(false) }
      end

      context "with missing closing parenthesis" do
        let(:text) { "This has [a link](https://example.com" }
        it { is_expected.to eq(false) }
      end
    end

    context "with unclosed raw HTML tags" do
      let(:text) { "This has <strong>bold text" }
      it { is_expected.to eq(false) }

      context "with just opening tag" do
        let(:text) { "This ends with <div" }
        it { is_expected.to eq(false) }
      end
    end

    context "with trailing incomplete URLs" do
      let(:text) { "Check out this link https://example" }
      it { is_expected.to eq(false) }

      context "when complete URL ending with punctuation is fine" do
        let(:text) { "Check out this link (https://example.com)." }
        it { is_expected.to eq(true) }
      end
    end

    context "with unclosed backticks" do
      let(:text) { "This has `code that doesn't close" }
      it { is_expected.to eq(false) }
    end

    context "with unbalanced bold or italic" do
      let(:text) { "This has **bold text but missing closing" }
      it { is_expected.to eq(false) }

      context "with odd number of asterisks" do
        let(:text) { "This has *italic text but missing closing" }
        it { is_expected.to eq(false) }
      end

      context "with odd number of underscores" do
        let(:text) { "This has _italic text but missing closing" }
        it { is_expected.to eq(false) }
      end
    end

    context "with incomplete image markdown" do
      let(:text) { "This has an image ![alt text](https://example.com/image" }
      it { is_expected.to eq(false) }
    end

    context "with unbalanced quote blocks" do
      let(:text) { "This has [quote]a quote but no closing tag" }
      it { is_expected.to eq(false) }

      context "with attributed quotes" do
        let(:text) { "This has [quote=User]a quote but no closing tag" }
        it { is_expected.to eq(false) }
      end

      context "when balanced is fine" do
        let(:text) { "This has [quote]a quote[/quote] that closes properly" }
        it { is_expected.to eq(true) }
      end
    end

    context "with unclosed triple backticks" do
      let(:text) { "This has ```a code block but no closing" }
      it { is_expected.to eq(false) }
    end

    context "with partial emoji" do
      let(:text) { "This has a partial :heart emoji" }
      it { is_expected.to eq(false) }

      context "with just the opening colon" do
        let(:text) { "This has a : that could start an emoji" }
        it { is_expected.to eq(true) } # This should be safe as it's just a colon
      end

      context "with emoji-like construct" do
        let(:text) { "This has a :something. at the end" }
        it { is_expected.to eq(false) }
      end
    end

    context "with HTML that needs sanitizing" do
      let(:text) { "<span>This text has HTML tags</span> but is otherwise safe" }
      it { is_expected.to eq(true) }

      context "with escaped HTML entities" do
        let(:text) { "This text has &lt;tags&gt; as entities" }
        it { is_expected.to eq(true) }
      end
    end
  end
end
