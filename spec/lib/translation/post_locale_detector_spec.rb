# frozen_string_literal: true

describe DiscourseAi::Translation::PostLocaleDetector do
  describe ".detect_locale" do
    fab!(:post) { Fabricate(:post, raw: "Hello world", locale: nil) }

    def language_detector_stub(opts)
      mock = instance_double(DiscourseAi::Translation::LanguageDetector)
      allow(DiscourseAi::Translation::LanguageDetector).to receive(:new).with(
        opts[:text],
      ).and_return(mock)
      allow(mock).to receive(:detect).and_return(opts[:locale])
    end

    it "returns nil if post is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "updates the post locale with the detected locale" do
      language_detector_stub({ text: post.raw, locale: "zh_CN" })
      expect { described_class.detect_locale(post) }.to change { post.reload.locale }.from(nil).to(
        "zh_CN",
      )
    end

    it "bypasses validations when updating locale" do
      post.update_column(:raw, "A")

      language_detector_stub({ text: post.raw, locale: "zh_CN" })

      described_class.detect_locale(post)
      expect(post.reload.locale).to eq("zh_CN")
    end
  end
end
