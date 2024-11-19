# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Mistral < OpenAi
        def self.can_contact?(model_provider)
          model_provider == "mistral"
        end
      end
    end
  end
end
