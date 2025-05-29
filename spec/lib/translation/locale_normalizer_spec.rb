# frozen_string_literal: true

describe DiscourseAi::Translation::LocaleNormalizer do
  it "matches input locales to i18n locales" do
    expect(described_class.normalize_to_i18n("en-GB")).to eq("en_GB")
    expect(described_class.normalize_to_i18n("en")).to eq("en")
    expect(described_class.normalize_to_i18n("zh")).to eq("zh_CN")
    expect(described_class.normalize_to_i18n("tr")).to eq("tr_TR")
  end

  it "converts dashes to underscores" do
    expect(described_class.normalize_to_i18n("a-b")).to eq("a_b")
  end
end
