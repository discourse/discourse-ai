# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Fake < Dialect
        class << self
          def can_translate?(model_name)
            model_name == "fake"
          end

          def tokenizer
            DiscourseAi::Tokenizer::OpenAiTokenizer
          end
        end

        def translate
          ""
        end
      end
    end
  end
end
