# frozen_string_literal: true

class LlmModel < ActiveRecord::Base
  def tokenizer_class
    tokenizer.constantize
  end
end
