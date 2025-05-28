# frozen_string_literal: true

describe DiscourseAi::Translation::ContentSplitter do
  let(:original_limit) { 4000 }

  after { described_class.const_set(:CHUNK_SIZE, original_limit) }

  def set_limit(value)
    described_class.const_set(:CHUNK_SIZE, value)
  end

  it "returns empty array for empty input" do
    expect(described_class.split("")).to eq([""])
  end

  it "handles content with only spaces" do
    expect(described_class.split(" ")).to eq([" "])
    expect(described_class.split("  ")).to eq(["  "])
  end

  it "handles nil input" do
    expect(described_class.split(nil)).to eq([])
  end

  it "doesn't split content under limit" do
    text = "hello world"
    expect(described_class.split(text)).to eq([text])
  end

  it "preserves HTML tags" do
    set_limit(10)
    text = "<p>hello</p><p>meow</p>"
    expect(described_class.split(text)).to eq(%w[<p>hello</p> <p>meow</p>])

    set_limit(35)
    text = "<div>hello</div> <div>jurassic</div> <p>world</p>"
    expect(described_class.split(text)).to eq(
      ["<div>hello</div> <div>jurassic</div>", " <p>world</p>"],
    )
  end

  it "preserves BBCode tags" do
    set_limit(20)
    text = "[quote]hello[/quote][details]world[/details]"
    expect(described_class.split(text)).to eq(["[quote]hello[/quote]", "[details]world[/details]"])
  end

  it "doesn't split in middle of words" do
    set_limit(10)
    text = "my kitty best in the world"
    expect(described_class.split(text)).to eq(["my kitty ", "best in ", "the world"])
  end

  it "handles nested tags properly" do
    set_limit(25)
    text = "<div>hello<p>cat</p>world</div><p>meow</p>"
    expect(described_class.split(text)).to eq(%w[<div>hello<p>cat</p>world</div> <p>meow</p>])
  end

  it "handles mixed HTML and BBCode" do
    set_limit(15)
    text = "<div>hello</div>[quote]world[/quote]<p>beautiful</p>"
    expect(described_class.split(text)).to eq(
      ["<div>hello</div>", "[quote]world[/quote]", "<p>beautiful</p>"],
    )
  end

  it "preserves newlines in sensible places" do
    set_limit(10)
    text = "hello\nbeautiful\nworld\n"
    expect(described_class.split(text)).to eq(["hello\n", "beautiful\n", "world\n"])
  end

  it "handles email content properly" do
    set_limit(20)
    text = "From: test@test.com\nTo: other@test.com\nSubject: Hello\n\nContent here"
    expect(described_class.split(text)).to eq(
      ["From: test@test.com\n", "To: other@test.com\n", "Subject: Hello\n\n", "Content here"],
    )
  end

  it "keeps code blocks intact" do
    set_limit(30)
    text = "Text\n```\ncode block\nhere\n```\nmore text"
    expect(described_class.split(text)).to eq(["Text\n```\ncode block\nhere\n```\n", "more text"])
  end

  context "with multiple details tags" do
    it "splits correctly between details tags" do
      set_limit(30)
      text = "<details>first content</details><details>second content</details>"
      expect(described_class.split(text)).to eq(
        ["<details>first content</details>", "<details>second content</details>"],
      )
    end
  end
end
