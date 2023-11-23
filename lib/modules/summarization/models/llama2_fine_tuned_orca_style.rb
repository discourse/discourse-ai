# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Models
      class Llama2FineTunedOrcaStyle < Llama2
        def display_name
          "Llama2FineTunedOrcaStyle's #{SiteSetting.ai_hugging_face_model_display_name.presence || model}"
        end
      end
    end
  end
end
