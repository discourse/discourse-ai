# frozen_string_literal: true

module ::DiscourseAI
  class Classification
    def initialize(classification_model)
      @classification_model = classification_model
    end

    def classify!(target)
      return :cannot_classify unless classification_model.can_classify?(target)

      classification_model
        .request(target)
        .tap do |classification|
          store_classification(target, classification_model.type, classification)

          if classification_model.should_flag_based_on?(classification)
            flag!(target, classification)
          end
        end
    end

    protected

    attr_reader :classification_model

    def flag!(_target, _classification)
      raise NotImplemented
    end

    def store_classification(_target, _classification)
      raise NotImplemented
    end

    def flagger
      Discourse.system_user
    end
  end
end
