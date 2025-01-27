# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::DiffUtils::SimpleDiff do
  subject { described_class }

  describe ".apply" do
    it "raises error for nil inputs" do
      expect { subject.apply(nil, "search", "replace") }.to raise_error(ArgumentError)
      expect { subject.apply("content", nil, "replace") }.to raise_error(ArgumentError)
      expect { subject.apply("content", "search", nil) }.to raise_error(ArgumentError)
    end

    it "raises error when no match is found" do
      content = "line1\ncompletely_different\nline3"
      search = "nothing_like_this"
      replace = "new_line"

      expect { subject.apply(content, search, replace) }.to raise_error(
        DiscourseAi::Utils::DiffUtils::SimpleDiff::NoMatchError,
      )
    end

    it "raises error for ambiguous matches" do
      content = "line1\nline2\nmiddle\nline2\nend"
      search = "line2"
      replace = "new_line2"

      expect { subject.apply(content, search, replace) }.to raise_error(
        DiscourseAi::Utils::DiffUtils::SimpleDiff::AmbiguousMatchError,
      )
    end

    it "replaces exact matches" do
      content = "line1\nline2\nline3"
      search = "line2"
      replace = "new_line2"

      expect(subject.apply(content, search, replace)).to eq("line1\nnew_line2\nline3")
    end

    it "handles multi-line replacements" do
      content = "start\nline1\nline2\nend"
      search = "line1\nline2"
      replace = "new_line"

      expect(subject.apply(content, search, replace)).to eq("start\nnew_line\nend")
    end

    it "is forgiving of whitespace differences" do
      content = "line1\n  line2\nline3"
      search = "line2"
      replace = "new_line2"

      expect(subject.apply(content, search, replace)).to eq("line1\nnew_line2\nline3")
    end

    it "is forgiving of small character differences" do
      content = "line one one one\nlin2\nline three three" # Notice 'lin2' instead of 'line2'
      search = "line2"
      replace = "new_line2"

      expect(subject.apply(content, search, replace)).to eq(
        "line one one one\nnew_line2\nline three three",
      )
    end

    it "is forgiving in multi-line blocks with indentation differences" do
      content = "def method\n    line1\n  line2\nend"
      search = "line1\nline2"
      replace = "new_content"

      expect(subject.apply(content, search, replace)).to eq("def method\nnew_content\nend")
    end
  end
end
