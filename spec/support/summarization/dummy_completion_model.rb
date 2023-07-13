# frozen_string_literal: true

class DummyCompletionModel
  SINGLE_SUMMARY = "this is a single summary"
  CONCATENATED_SUMMARIES = "this is a concatenated summary"

  def initialize(max_tokens)
    @summarization_calls = 0
    @available_tokens = max_tokens
  end

  attr_reader :max_length, :summarization_calls, :available_tokens

  delegate :can_expand_tokens?, to: :tokenizer

  def summarize_single(single_chunk, opts)
    @summarization_calls += 1
    SINGLE_SUMMARY
  end

  def summarize_in_chunks(chunks, opts)
    chunks.map do |chunk|
      chunk[:summary] = SINGLE_SUMMARY
      @summarization_calls += 1
      chunk
    end
  end

  def concatenate_summaries(summaries)
    @summarization_calls += 1
    CONCATENATED_SUMMARIES
  end

  def summarize_with_truncation(_contents, _opts)
    @summarization_calls += 1
    SINGLE_SUMMARY
  end

  def format_content_item(item)
    "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "
  end

  def tokenizer
    DiscourseAi::Tokenizer::BertTokenizer
  end
end
