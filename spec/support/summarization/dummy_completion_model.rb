# frozen_string_literal: true

class DummyCompletionModel
  SINGLE_SUMMARY = "this is a single summary"
  CONCATENATED_SUMMARIES = "this is a concatenated summary"

  def initialize(prompt_length)
    @max_length = prompt_length
    @summarization_calls = 0
  end

  attr_reader :max_length, :summarization_calls

  def summarize_in_chunks(contents, _opts)
    contents.reduce("") do |memo, item|
      new_content = "(#{item[:id]} #{item[:poster]} said: #{item[:text]} "

      if tokenizer.can_expand_tokens?(memo, new_content, max_length)
        memo << new_content
      else
        @summarization_calls += 1
        memo = ""
      end

      memo
    end

    [SINGLE_SUMMARY] * @summarization_calls
  end

  def concatenate_summaries(summaries)
    @summarization_calls += 1
    CONCATENATED_SUMMARIES
  end

  def summarize_with_truncation(_contents, _opts)
    @summarization_calls += 1
    SINGLE_SUMMARY
  end

  def tokenizer
    DiscourseAi::Tokenizer::BertTokenizer
  end
end
