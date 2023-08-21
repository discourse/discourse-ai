# frozen_string_literal: true

require_relative "../../../../support/openai_completions_inference_stubs"

RSpec.describe DiscourseAi::Summarization::Models::OpenAi do
  subject(:model) { described_class.new(model_name, max_tokens: max_tokens) }

  let(:model_name) { "gpt-3.5-turbo" }
  let(:max_tokens) { 720 }

  let(:content) do
    {
      resource_path: "/t/1/POST_NUMBER",
      content_title: "This is a title",
      contents: [{ poster: "asd", id: 1, text: "This is a text" }],
    }
  end

  def as_chunk(item)
    { ids: [item[:id]], summary: "(#{item[:id]} #{item[:poster]} said: #{item[:text]} " }
  end

  def expected_messages(contents, opts)
    base_prompt = <<~TEXT
      You are a summarization bot.
      You effectively summarise any text and reply ONLY with ONLY the summarized text.
      You condense it into a shorter version.
      You understand and generate Discourse forum Markdown.
      You format the response, including links, using markdown.
      Try generating links as well the format is #{opts[:resource_path]}. eg: [ref](#{opts[:resource_path]}/77)
      The discussion title is: #{opts[:content_title]}.
    TEXT

    messages = [{ role: "system", content: base_prompt }]

    text =
      contents.reduce("") do |memo, item|
        memo += "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
      end

    messages << { role: "user", content: "Summarize the following in 400 words. Keep the summary in the same language used in the text below.\n#{text}" }
  end

  describe "#summarize_in_chunks" do
    context "when the content fits in a single chunk" do
      it "performs a request to summarize" do
        opts = content.except(:contents)

        OpenAiCompletionsInferenceStubs.stub_response(
          expected_messages(content[:contents], opts),
          "This is summary 1",
        )

        chunks = content[:contents].map { |c| as_chunk(c) }
        summarized_chunks = model.summarize_in_chunks(chunks, opts).map { |c| c[:summary] }

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
          OpenAiCompletionsInferenceStubs.stub_response(
            expected_messages([item], opts),
            "This is summary #{idx + 1}",
          )
        end

        chunks = content[:contents].map { |c| as_chunk(c) }
        summarized_chunks = model.summarize_in_chunks(chunks, opts).map { |c| c[:summary] }

        expect(summarized_chunks).to contain_exactly("This is summary 1", "This is summary 2")
      end
    end
  end

  describe "#concatenate_summaries" do
    it "combines all the different summaries into a single one" do
      messages = [
        { role: "system", content: "You are a helpful bot" },
        {
          role: "user",
          content:
            "Concatenate these disjoint summaries, creating a cohesive narrative. Keep the summary in the same language used in the text below.\nsummary 1\nsummary 2",
        },
      ]

      OpenAiCompletionsInferenceStubs.stub_response(messages, "concatenated summary")

      expect(model.concatenate_summaries(["summary 1", "summary 2"])).to eq("concatenated summary")
    end
  end

  describe "#summarize_with_truncation" do
    let(:max_tokens) { 709 }

    it "truncates the context to meet the token limit" do
      opts = content.except(:contents)

      truncated_version = expected_messages(content[:contents], opts)

      truncated_version.last[
        :content
      ] = "Summarize the following in 400 words. Keep the summary in the same language used in the text below.\n(1 asd said: This is a"

      OpenAiCompletionsInferenceStubs.stub_response(truncated_version, "truncated summary")

      expect(model.summarize_with_truncation(content[:contents], opts)).to eq("truncated summary")
    end
  end
end
