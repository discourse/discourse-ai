# frozen_string_literal: true

require_relative "../../../../support/anthropic_completion_stubs"

RSpec.describe DiscourseAi::Summarization::Models::Anthropic do
  subject(:model) { described_class.new(model_name, max_tokens: max_tokens) }

  let(:model_name) { "claude-v1" }
  let(:max_tokens) { 720 }

  let(:content) do
    {
      resource_path: "/t/1/POST_NUMBER",
      content_title: "This is a title",
      contents: [{ poster: "asd", id: 1, text: "This is a text" }],
    }
  end

  def expected_messages(contents, opts)
    base_prompt = <<~TEXT
      Human: Summarize the following forum discussion inside the given <input> tag.
      Include only the summary inside <ai> tags.
      Try generating links as well the format is #{opts[:resource_path]}.
      The discussion title is: #{opts[:content_title]}.
      Don't use more than 400 words.
    TEXT

    text =
      contents.reduce("") do |memo, item|
        memo += "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
      end

    base_prompt += "<input>#{text}</input>\nAssistant:\n"
  end

  describe "#summarize_in_chunks" do
    context "when the content fits in a single chunk" do
      it "performs a request to summarize" do
        opts = content.except(:contents)

        AnthropicCompletionStubs.stub_response(
          expected_messages(content[:contents], opts),
          "<ai>This is summary 1</ai>",
        )

        summarized_chunks =
          model.summarize_in_chunks(content[:contents], opts).map { |c| c[:summary] }

        expect(summarized_chunks).to contain_exactly("This is summary 1")
      end
    end

    context "when the content fits in multiple chunks" do
      it "performs a request for each one to summarize" do
        content[:contents] << {
          poster: "asd2",
          id: 2,
          text: "This is a different text to summarize",
        }
        opts = content.except(:contents)

        content[:contents].each_with_index do |item, idx|
          AnthropicCompletionStubs.stub_response(
            expected_messages([item], opts),
            "<ai>This is summary #{idx + 1}</ai>",
          )
        end

        summarized_chunks =
          model.summarize_in_chunks(content[:contents], opts).map { |c| c[:summary] }

        expect(summarized_chunks).to contain_exactly("This is summary 1", "This is summary 2")
      end
    end
  end

  describe "#concatenate_summaries" do
    it "combines all the different summaries into a single one" do
      messages = <<~TEXT
        Human: Concatenate the following disjoint summaries inside the given input tags, creating a cohesive narrative.
        Include only the summary inside <ai> tags.
        <input>summary 1</input>
        <input>summary 2</input>
        Assistant:
      TEXT

      AnthropicCompletionStubs.stub_response(messages, "<ai>concatenated summary</ai>")

      expect(model.concatenate_summaries(["summary 1", "summary 2"])).to eq("concatenated summary")
    end
  end

  describe "#summarize_with_truncation" do
    let(:max_tokens) { 709 }

    it "truncates the context to meet the token limit" do
      opts = content.except(:contents)

      instructions = <<~TEXT
        Human: Summarize the following forum discussion inside the given <input> tag.
        Include only the summary inside <ai> tags.
        Try generating links as well the format is #{opts[:resource_path]}.
        The discussion title is: #{opts[:content_title]}.
        Don't use more than 400 words.
        <input>(1 asd said: This is a</input>
        Assistant:
      TEXT

      AnthropicCompletionStubs.stub_response(instructions, "<ai>truncated summary</ai>")

      expect(model.summarize_with_truncation(content[:contents], opts)).to eq("truncated summary")
    end
  end
end
